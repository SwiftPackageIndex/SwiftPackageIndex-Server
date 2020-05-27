import Vapor


enum Github {
    struct License: Decodable, Equatable {
        var key: String
    }

    struct Metadata: Decodable, Equatable {
        var openPullRequests: [Pull]
        var repo: Repo

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

        struct Pull: Decodable, Equatable {
            var id: Int
        }
    }

    static func fetchMetadata(client: Client, package: Package) -> EventLoopFuture<Metadata> {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            let url = try apiUri(for: package)
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
                            .init(openPullRequests: [], repo: $0)
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

    static func apiUri(for package: Package) throws -> URI {
        guard package.url.hasPrefix(Constants.githubComPrefix) else { throw AppError.invalidPackageUrl(package.id, package.url) }
        let trunk = package.url
            .droppingGithubComPrefix
            .droppingGitExtension
        return URI(string: "https://api.github.com/repos/\(trunk)")
    }
}
