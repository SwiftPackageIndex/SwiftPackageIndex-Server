import Vapor


enum Github {
    struct License: Decodable, Equatable {
        var key: String
    }

    struct Metadata: Decodable, Equatable {
        var issues: [Issue]
        var openPullRequests: [Pull]
        var repo: Repo

        // Content from https://api.github.com/repos/${repo}/issues
        struct Issue: Decodable, Equatable {
            var closedAt: Date?
            var pullRequest: Pull?
        }

        // Content from https://api.github.com/repos/${repo}/pulls
        struct Pull: Decodable, Equatable {
            var id: Int
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
    }

    enum Error: LocalizedError {
        case requestFailed(HTTPStatus, URI)
    }

    static var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    static func fetchResource<T: Decodable>(_ type: T.Type, client: Client, uri: URI) -> EventLoopFuture<T> {
        let request = client
            .get(uri, headers: getHeaders)
            .flatMap { response -> EventLoopFuture<T> in
                guard response.status == .ok else {
                    return client.eventLoop.future(error:
                        Error.requestFailed(response.status, uri)
                    )
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
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            let url = try apiUri(for: package, resource: .repo)
            let request = client
                .get(url, headers: getHeaders)
                .flatMap { response -> EventLoopFuture<Metadata> in
                    guard response.status == .ok else {
                        return client.eventLoop.future(error:
                            AppError.metadataRequestFailed(package.id, response.status, url)
                        )
                    }
                    do {
                        return client.eventLoop.future(
                            try response.content
                                .decode(Metadata.Repo.self, using: decoder)
                        ).map {
                            .init(issues: [],
                                  openPullRequests: [],
                                  repo: $0)
                        }
                    } catch {
                        return client.eventLoop.future(error: error)
                    }
                }
            return request
        } catch {
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
        let queryString = query.isEmpty
            ? ""
            : "?" + query.keys.sorted().map { key in "\(key)=\(query[key]!)" }.joined(separator: "&")
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
