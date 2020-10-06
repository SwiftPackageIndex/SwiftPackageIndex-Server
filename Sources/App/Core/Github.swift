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
    
    static func isRateLimited(_ response: ClientResponse) -> Bool {
        if
            response.status == .forbidden,
            let header = response.headers.first(name: "X-RateLimit-Remaining"),
            let limit = Int(header) {
            return limit == 0
        }
        return false
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
        let headers = HTTPHeaders([("User-Agent", "SPI-Server"),
                                   ("Authorization", "Bearer \(token)")])
        return client.post(Self.graphQLApiUri, headers: headers) { req in
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


extension Github {

    struct Metadata: Decodable, Equatable {
        static func query(owner: String, repository: String) -> GraphQLQuery {
            // Go to https://developer.github.com/v4/explorer/ to run query manually
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
                    }
                    stargazerCount
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
            var stargazerCount: Int
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
        }
        struct OpenPullRequests: Decodable, Equatable {
            var totalCount: Int
        }
    }

}
