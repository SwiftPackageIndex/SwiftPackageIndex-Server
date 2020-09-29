import Vapor


enum Github {
    struct License: Decodable, Equatable {
        var key: String
    }
    
    // Content from https://api.github.com/repos/${repo}/issues
    struct Issue: Decodable, Equatable {
        var closedAt: Date?
        var pullRequest: Pull?
    }
    
    // Content from https://api.github.com/repos/${repo}/pulls
    struct Pull: Decodable, Equatable {
        var url: String
    }
    
    // Content from https://api.github.com/repos/${repo}
    struct Repo: Decodable, Equatable {
        var defaultBranch: String
        var description: String?
        var forksCount: Int
        var license: License?
        var name: String?
        var openIssues: Int
        var owner: Owner?
        var parent: Parent?
        var stargazersCount: Int
        
        struct Parent: Decodable, Equatable {
            var cloneUrl: String
            var fullName: String
            var url: String
        }
        
        struct Owner: Decodable, Equatable {
            var login: String?
        }
    }
    
    struct Metadata: Decodable, Equatable {
        var issues: [Issue]
        var openPullRequests: [Pull]
        var repo: Repo
    }
    
    enum Error: LocalizedError {
        case missingToken
        case invalidURI(Package.Id?, _ url: String)
        case requestFailed(HTTPStatus, URI)

        var errorDescription: String? {
            switch self {
                case .missingToken:
                    return "missing Github API token"
                case let .invalidURI(id, url):
                    return "invalid URL: \(url) (id: \(id?.uuidString ?? "nil"))"
                case let .requestFailed(statusCode, uri):
                    return "request failed with status code '\(statusCode)' (uri: \(uri))"
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
    
    static func fetchResource<T: Decodable>(_ type: T.Type, client: Client, uri: URI) -> EventLoopFuture<T> {
        let request = client
            .get(uri, headers: getHeaders)
            .flatMap { response -> EventLoopFuture<T> in
                guard !isRateLimited(response) else {
                    return Current
                        .reportError(client,
                                     .critical,
                                     AppError.metadataRequestFailed(nil, .tooManyRequests, uri))
                        .flatMap {
                            client.eventLoop.future(error: Error.requestFailed(.tooManyRequests, uri))
                        }
                }
                guard response.status == .ok else {
                    return client.eventLoop.future(error: Error.requestFailed(response.status, uri))
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
    
    static func fetchMetadata(client: Client, package: Package) -> EventLoopFuture<Metadata> {
        guard
            let repoUri = try? apiUri(for: package, resource: .repo),
            let issuesUri = try? apiUri(for: package, resource: .issues, query: ["state": "closed",
                                                                                 "sort": "closed",
                                                                                 "direction": "desc",
                                                                                 "page_size": "100"]),
            let pullsUri = try? apiUri(for: package, resource: .pulls, query: ["state": "open",
                                                                               "sort": "updated",
                                                                               "direction": "desc",
                                                                               "page_size": "100"])
        else { return client.eventLoop.future(error: Error.invalidURI(package.id, package.url)) }
        
        // Chain requests together
        let issues = fetchResource([Issue].self, client: client, uri: issuesUri)
        let pulls = fetchResource([Pull].self, client: client, uri: pullsUri)
        let repo = fetchResource(Repo.self, client: client, uri: repoUri)
        
        let metadata = issues.and(pulls).and(repo)
            .map { ($0.0, $0.1, $1) }  // unpack into (issues, pulls, repo) tuple
            .map(Metadata.init)
        
        return metadata
            .flatMapError { error in
                // remap request failures to AppError
                if case let Github.Error.requestFailed(status, uri) = error {
                    return client.eventLoop.future(error: AppError.metadataRequestFailed(package.id, status, uri))
                }
                return client.eventLoop.future(error: error)
            }
    }
    
    static var getHeaders: HTTPHeaders {
        // Set User-Agent or we get a 403
        // https://developer.github.com/v3/#user-agent-required
        var headers = HTTPHeaders([("User-Agent", "SPI-Server")])
        if let token = Current.githubToken() {
            headers.add(name: "Authorization", value: "token \(token)")
        }
        return headers
    }
    
    enum Resource: String {
        case issues
        case pulls
        case repo
    }
    
    static func apiUri(for package: Package,
                       resource: Resource,
                       query: [String: String] = [:]) throws -> URI {
        guard package.url.hasPrefix(Constants.githubComPrefix) else { throw AppError.invalidPackageUrl(package.id, package.url) }
        let queryString = query.queryString()
        let trunk = package.url
            .droppingGithubComPrefix
            .droppingGitExtension
        switch resource {
            case .issues, .pulls:
                return URI(string: "https://api.github.com/repos/\(trunk)/\(resource.rawValue)\(queryString)")
            case .repo:
                return URI(string: "https://api.github.com/repos/\(trunk)\(queryString)")
        }
    }
}


// MARK: - GraphQL

extension Github {

    static let graphQLApiUri = URI(string: "https://api.github.com/graphql")

    struct GraphQLQuery: Content {
        var query: String
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

    static func fetchResource<T: Decodable>(_ type: T.Type, client: Client, query: GraphQLQuery) -> EventLoopFuture<T> {
        guard let token = Current.githubToken() else {
            return client.eventLoop.future(error: Error.missingToken)
        }
        let headers = HTTPHeaders([("User-Agent", "SPI-Server"),
                                   ("Authorization", "Bearer \(token)")])
        return client.post(Self.graphQLApiUri, headers: headers) { req in
            try req.content.encode(query)
        }
        .flatMapThrowing { response in
            guard response.status == .ok else {
                throw Error.requestFailed(response.status, Self.graphQLApiUri)
            }
            return try response.content.decode(T.self, using: decoder)
        }
    }

    struct _Metadata: Decodable, Equatable {
        static func query(owner: String, repository: String) -> GraphQLQuery {
            // Go to https://developer.github.com/v4/explorer/ to run query manually
            GraphQLQuery(query: """
                {
                  repository(name: "\(repository)", owner: "\(owner)") {
                    closedIssues: issues(states: CLOSED, first: 100, orderBy: {field: UPDATED_AT, direction: DESC}) {
                      edges {
                        node {
                          closedAt
                        }
                      }
                    }
                    closedPullRequests: pullRequests(states: CLOSED, first: 1, orderBy: {field: UPDATED_AT, direction: DESC}) {
                      edges {
                        node {
                          closedAt
                        }
                      }
                    }
                    createdAt
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
                    mergedPullRequests: pullRequests(states: MERGED, first: 1, orderBy: {field: UPDATED_AT, direction: DESC}) {
                      edges {
                        node {
                          closedAt
                        }
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
                  rateLimit {
                    remaining
                  }
                }
                """)
        }
        var repository: Repository
        var rateLimit: RateLimit

        struct Repository: Decodable, Equatable {
            var closedIssues: NodeEdges
            var closedPullRequests: NodeEdges
            var createdAt: Date
            var defaultBranchRef: DefaultBranchRef
            var description: String
            var forkCount: Int
            var isArchived: Bool
            var isFork: Bool
            var licenseInfo: LicenseInfo
            var mergedPullRequests: NodeEdges
            var name: String
            var openIssues: OpenIssues
            var openPullRequests: OpenPullRequests
            var owner: Owner
            var stargazerCount: Int
            // derived properties
            var defaultBranch: String { defaultBranchRef.name }
            var lastIssueClosedAt: Date? {
                closedIssues.edges
                    .map(\.node.closedAt)
                    .sorted()
                    .last
            }
            var lastPullRequestClosedAt: Date? {
                switch (
                    closedPullRequests.edges.first?.node.closedAt,
                    mergedPullRequests.edges.first?.node.closedAt) {
                    case (.none, .none):
                        return nil
                    case (.some(let value), .none):
                        return value
                    case (.none, .some(let value)):
                        return value
                    case let (.some(lhs), .some(rhs)):
                        return max(lhs, rhs)
                }
            }
        }
        struct NodeEdges: Decodable, Equatable {
            var edges: [Edge]
            struct Edge: Decodable, Equatable {
                var node: Node

                struct Node: Decodable, Equatable {
                    var closedAt: Date
                }
            }
        }
        struct DefaultBranchRef: Decodable, Equatable {
            var name: String
        }
        struct LicenseInfo: Decodable, Equatable {
            var name: String
            var key: String
            var url: String
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
        struct RateLimit: Decodable, Equatable {
            var remaining: Int
        }
    }

    static func fetchMetadata(client: Client, owner: String, repository: String) -> EventLoopFuture<_Metadata> {
        struct Response: Decodable, Equatable {
            var data: _Metadata
        }
        return fetchResource(Response.self,
                             client: client,
                             query: _Metadata.query(owner: owner, repository: repository))
            .map(\.data)
    }

}
