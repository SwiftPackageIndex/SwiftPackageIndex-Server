import Vapor


enum Github {

    enum Error: LocalizedError {
        case missingToken
        case invalidURI(Package.Id?, _ url: String)
        case requestFailed(HTTPStatus)

        var errorDescription: String? {
            switch self {
                case .missingToken:
                    return "missing Github API token"
                case let .invalidURI(id, url):
                    return "invalid URL: \(url) (id: \(id?.uuidString ?? "nil"))"
                case .requestFailed(let statusCode):
                    return "request failed with status code: \(statusCode)"
            }
        }
    }
    
    static var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func rateLimit(response: ClientResponse) -> Int? {
        guard
            let header = response.headers.first(name: "X-RateLimit-Remaining"),
            let limit = Int(header)
        else { return nil }
        return limit
    }

    static func isRateLimited(_ response: ClientResponse) -> Bool {
        guard let limit = rateLimit(response: response) else { return false }
        AppMetrics.githubRateLimitRemainingCount?.set(limit)
        return response.status == .forbidden && limit == 0
    }

    static func parseOwnerName(url: String) throws -> (owner: String, name: String) {
        let parts = url
            .droppingGithubComPrefix
            .droppingGitExtension
            .split(separator: "/")
            .map(String.init)
        guard parts.count == 2 else { throw Error.invalidURI(nil, url) }
        return (owner: parts[0], name: parts[1])
    }

    static func headers(with token: String) -> HTTPHeaders {
        // Set User-Agent or we get a 403
        // https://developer.github.com/v3/#user-agent-required
        HTTPHeaders([("User-Agent", "SPI-Server"),
                     ("Authorization", "Bearer \(token)")])
    }

}

// MARK: - REST API

extension Github {

    enum Resource: String {
        case license
        case readme
    }

    static func apiUri(for package: Package,
                       resource: Resource,
                       query: [QueryParameter] = []) throws -> URI {
        guard package.url.hasPrefix(Constants.githubComPrefix) else { throw AppError.invalidPackageUrl(package.id, package.url) }
        let queryString = query.queryString()
        let trunk = package.url
            .droppingGithubComPrefix
            .droppingGitExtension
        switch resource {
            case .license, .readme:
                return URI(string: "https://api.github.com/repos/\(trunk)/\(resource.rawValue)\(queryString)")
        }
    }

    static func fetchResource<T: Decodable>(_ type: T.Type, client: Client, uri: URI) -> EventLoopFuture<T> {
        guard let token = Current.githubToken() else {
            return client.eventLoop.future(error: Error.missingToken)
        }
        let request = client
            .get(uri, headers: headers(with: token))
            .flatMap { response -> EventLoopFuture<T> in
                guard !isRateLimited(response) else {
                    return Current
                        .reportError(client,
                                     .critical,
                                     AppError.metadataRequestFailed(nil, .tooManyRequests, uri))
                        .flatMap {
                            client.eventLoop.future(error: Error.requestFailed(.tooManyRequests))
                        }
                }
                guard response.status == .ok else {
                    return client.eventLoop.future(error: Error.requestFailed(response.status))
                }
                do {
                    let res = try response.content.decode(T.self, using: decoder)
                    return client.eventLoop.future(res)
                } catch {
                    return client.eventLoop.future(error: error)
                }
            }
        return request
    }

    static func fetchLicense(client: Client, package: Package) -> EventLoopFuture<License?> {
        do {
            let uri = try Github.apiUri(for: package, resource: .license)
            return Github.fetchResource(Github.License.self, client: client, uri: uri)
                .map { license -> License? in license }
                .recover { _ in nil }
        } catch {
            return client.eventLoop.future(error: error)
        }
    }

    static func fetchReadme(client: Client, package: Package) -> EventLoopFuture<Readme?> {
        do {
            let uri = try Github.apiUri(for: package, resource: .readme)
            return Github.fetchResource(Github.Readme.self, client: client, uri: uri)
                .map { readme -> Readme? in readme }
                .recover { _ in nil }
        } catch {
            return client.eventLoop.future(error: error)
        }
    }

}


// MARK: - GraphQL

extension Github {

    static let graphQLApiUri = URI(string: "https://api.github.com/graphql")

    struct GraphQLQuery: Content {
        var query: String
    }

    static func fetchResource<T: Decodable>(_ type: T.Type, client: Client, query: GraphQLQuery) -> EventLoopFuture<T> {
        guard let token = Current.githubToken() else {
            return client.eventLoop.future(error: Error.missingToken)
        }
        return client.post(Self.graphQLApiUri, headers: headers(with: token)) { req in
            try req.content.encode(query)
        }
        .flatMap { response -> EventLoopFuture<ClientResponse> in
            guard !isRateLimited(response) else {
                return Current
                    .reportError(client,
                                 .critical,
                                 AppError.metadataRequestFailed(nil,
                                                                .tooManyRequests,
                                                                Self.graphQLApiUri))
                    .flatMap {
                        client.eventLoop.future(error: Error.requestFailed(.tooManyRequests))
                    }
            }
            return client.eventLoop.future(response)
        }
        .flatMapThrowing { response in
            guard response.status == .ok else {
                throw Error.requestFailed(response.status)
            }
            return try response.content.decode(T.self, using: decoder)
        }
    }

    static func fetchMetadata(client: Client, owner: String, repository: String) -> EventLoopFuture<Metadata> {
        struct Response: Decodable, Equatable {
            var data: Metadata
        }
        return fetchResource(Response.self,
                             client: client,
                             query: Metadata.query(owner: owner, repository: repository))
            .map(\.data)
    }

    static func fetchMetadata(client: Client, package: Package) -> EventLoopFuture<Metadata> {
        do {
            let (owner, name) = try parseOwnerName(url: package.url)
            return fetchMetadata(client: client, owner: owner, repository: name)
        } catch {
            return client.eventLoop.future(error: error)
        }
    }

}


// MARK: - Data transfer objects (DTOs)

extension Github {

    struct License: Decodable, Equatable {
        var htmlUrl: String
    }

    struct Readme: Decodable, Equatable {
        var downloadUrl: String
        var htmlUrl: String
    }

    struct Metadata: Decodable, Equatable {
        static func query(owner: String, repository: String) -> GraphQLQuery {
            // Go to https://developer.github.com/v4/explorer/ to run query manually
            // ⚠️ Important: consult the schema to determine which fields are optional
            // and make sure the Decodable properties are optional as well to avoid
            // decoding errors. Note that GraphQL uses sort of a reverse syntax to
            // Swift:
            // optionalField: String          -> var optionalField: String?
            // nonOptionalField: String!      -> var nonOptionalField: String
            GraphQLQuery(query: """
                {
                  repository(name: "\(repository)", owner: "\(owner)") {
                    closedIssues: issues(states: CLOSED, first: 100, orderBy: {field: UPDATED_AT, direction: DESC}) {
                      nodes {
                        closedAt
                      }
                    }
                    closedPullRequests: pullRequests(states: CLOSED, first: 100, orderBy: {field: UPDATED_AT, direction: DESC}) {
                      nodes {
                        closedAt
                      }
                    }
                    defaultBranchRef {
                      name
                    }
                    description
                    forkCount
                    isArchived
                    isFork
                    licenseInfo {
                      name
                      key
                      url
                    }
                    mergedPullRequests: pullRequests(states: MERGED, first: 100, orderBy: {field: UPDATED_AT, direction: DESC}) {
                      nodes {
                        closedAt
                      }
                    }
                    name
                    openIssues: issues(states: OPEN) {
                      totalCount
                    }
                    openPullRequests: pullRequests(states: OPEN) {
                      totalCount
                    }
                    owner {
                      login
                      avatarUrl
                      ... on User {
                        name
                      }
                      ... on Organization {
                        name
                      }
                    }
                    releases(first: 20, orderBy: {field: CREATED_AT, direction: DESC}) {
                      nodes {
                        description
                        isDraft
                        publishedAt
                        tagName
                        url
                      }
                    }
                    stargazerCount
                    isInOrganization
                  }
                }
                """)
        }
        var repository: Repository?

        struct Repository: Decodable, Equatable {
            var closedIssues: IssueNodes
            var closedPullRequests: IssueNodes
            var defaultBranchRef: DefaultBranchRef?
            var description: String?
            var forkCount: Int
            var isArchived: Bool
            var isFork: Bool
            var licenseInfo: LicenseInfo?
            var mergedPullRequests: IssueNodes
            var name: String
            var openIssues: OpenIssues
            var openPullRequests: OpenPullRequests
            var owner: Owner
            var releases: ReleaseNodes
            var stargazerCount: Int
            var isInOrganization: Bool
            // derived properties
            var defaultBranch: String? { defaultBranchRef?.name }
            var lastIssueClosedAt: Date? {
                closedIssues.nodes.map(\.closedAt).sorted().last
            }
            var lastPullRequestClosedAt: Date? {
                (closedPullRequests.nodes + mergedPullRequests.nodes).map(\.closedAt).sorted().last
            }
        }

        struct IssueNodes: Decodable, Equatable {
            var nodes: [IssueNode]

            struct IssueNode: Decodable, Equatable {
                var closedAt: Date
            }

            init(closedAtDates: [Date]) {
                self.nodes = closedAtDates
                    .map(IssueNode.init(closedAt:))
            }
        }

        struct DefaultBranchRef: Decodable, Equatable {
            var name: String
        }

        struct LicenseInfo: Decodable, Equatable {
            var name: String
            var key: String

            init(name: String = "", key: String) {
                self.name = name
                self.key = key
            }
        }

        struct OpenIssues: Decodable, Equatable {
            var totalCount: Int
        }

        struct Owner: Decodable, Equatable {
            var login: String
            var name: String?
            var avatarUrl: String
        }

        struct OpenPullRequests: Decodable, Equatable {
            var totalCount: Int
        }

        struct ReleaseNodes: Decodable, Equatable {
            var nodes: [ReleaseNode]

            struct ReleaseNode: Decodable, Equatable {
                var description: String?
                var isDraft: Bool
                var publishedAt: Date?
                var tagName: String
                var url: String
            }
        }
    }

}
