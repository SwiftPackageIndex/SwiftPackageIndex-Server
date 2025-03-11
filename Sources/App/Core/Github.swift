// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Dependencies
import S3Store
import SwiftSoup
import Vapor


enum Github {

    enum Error: Swift.Error {
        case decodeContentFailed(_ url: String, Swift.Error)
        case encodeContentFailed(_ url: String, Swift.Error)
        case missingToken
        case noBody
        case invalidURL(String)
        case postRequestFailed(_ url: String, Swift.Error)
        case requestFailed(HTTPStatus)
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func rateLimit(response: HTTPClient.Response) -> Int? {
        guard
            let header = response.headers.first(name: "X-RateLimit-Remaining"),
            let limit = Int(header)
        else { return nil }
        return limit
    }

    static func isRateLimited(_ response: HTTPClient.Response) -> Bool {
        guard let limit = rateLimit(response: response) else { return false }
        AppMetrics.githubRateLimitRemainingCount?.set(limit)
        return response.status == .forbidden && limit == 0
    }

    static func parseOwnerName(url: String) throws(Github.Error) -> (owner: String, name: String) {
        let parts = url
            .droppingGithubComPrefix
            .droppingGitExtension
            .split(separator: "/")
            .map(String.init)
        guard parts.count == 2 else { throw Error.invalidURL(url) }
        return (owner: parts[0], name: parts[1])
    }

    static func defaultHeaders(with token: String) -> HTTPHeaders {
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

    static func apiURL(owner: String, repository: String, resource: Resource)  -> String {
        switch resource {
            case .license, .readme:
                return "https://api.github.com/repos/\(owner)/\(repository)/\(resource.rawValue)"
        }
    }

    static func fetch(url: String, headers: [(String, String)] = []) async throws -> (content: String, etag: String?) {
        @Dependency(\.github) var github
        @Dependency(\.httpClient) var httpClient
        @Dependency(\.logger) var logger

        guard let token = github.token() else {
            throw Error.missingToken
        }


        let response = try await httpClient.get(url: url, headers: defaultHeaders(with: token).adding(contentsOf: headers))

        guard !isRateLimited(response) else {
            logger.critical("rate limited while fetching \(url)")
            throw Error.requestFailed(.tooManyRequests)
        }

        guard response.status == .ok else {
            logger.warning("Github.fetch of '\(url)' failed with status \(response.status)")
            throw Error.requestFailed(response.status)
        }

        guard let body = response.body else {
            logger.warning("Github.fetch has no body")
            throw Error.noBody
        }

        return (body.asString(), response.headers.first(name: .eTag))
    }

    static func fetchResource<T: Decodable>(_ type: T.Type, url: String) async throws -> T {
        @Dependency(\.github) var github
        @Dependency(\.logger) var logger

        guard let token = github.token() else {
            throw Error.missingToken
        }

        @Dependency(\.httpClient) var httpClient

        let response = try await httpClient.get(url: url, headers: defaultHeaders(with: token))

        guard !isRateLimited(response) else {
            logger.critical("rate limited while fetching resource \(url)")
            throw Error.requestFailed(.tooManyRequests)
        }

        guard response.status == .ok else { throw Error.requestFailed(response.status) }
        guard let body = response.body else { throw Github.Error.noBody }

        return try decoder.decode(T.self, from: body)
    }

    static func fetchLicense(owner: String, repository: String) async -> License? {
        let url = Github.apiURL(owner: owner, repository: repository, resource: .license)
        return try? await Github.fetchResource(Github.License.self, url: url)
    }

    static func fetchReadme(owner: String, repository: String) async -> Readme? {
        let url = Github.apiURL(owner: owner, repository: repository, resource: .readme)

        // Fetch readme html content
        let readme = try? await Github.fetch(url: url, headers: [
            ("Accept", "application/vnd.github.html+json")
        ])
        guard var html = readme?.content else { return nil }

        // Fetch readme html url
        let htmlUrl: String? = await {
            struct Response: Decodable {
                var htmlUrl: String
            }
            return try? await Github.fetchResource(Response.self, url: url).htmlUrl
        }()
        guard let htmlUrl else { return nil }

        // Extract and replace images that need caching
        let imagesToCache = replaceImagesRequiringCaching(owner: owner, repository: repository, readme: &html)

        return .init(etag: readme?.etag, html: html, htmlUrl: htmlUrl, imagesToCache: imagesToCache)
    }

}


// MARK: - GraphQL

extension Github {

    static let graphQLApiURL = "https://api.github.com/graphql"

    struct GraphQLQuery: Content {
        var query: String
    }

    static func fetchResource<T: Decodable>(_ type: T.Type, query: GraphQLQuery) async throws(Github.Error) -> T {
        @Dependency(\.github) var github
        @Dependency(\.httpClient) var httpClient
        @Dependency(\.logger) var logger

        guard let token = github.token() else {
            throw Error.missingToken
        }

        let body = try run {
            try JSONEncoder().encode(query)
        } rethrowing: {
            Error.encodeContentFailed(graphQLApiURL, $0)
        }

        let response = try await run {
            try await httpClient.post(url: graphQLApiURL, headers: defaultHeaders(with: token), body: body)
        } rethrowing: {
            Error.postRequestFailed(graphQLApiURL, $0)
        }

        guard !isRateLimited(response) else {
            logger.critical("rate limited while fetching resource \(T.self)")
            throw Error.requestFailed(.tooManyRequests)
        }

        guard response.status == .ok else {
            logger.warning("fetchResource<\(T.self)> request failed with status \(response.status)")
            throw Error.requestFailed(response.status)
        }

        guard let body = response.body else { throw Github.Error.noBody }

        return try run {
            try decoder.decode(T.self, from: body)
        } rethrowing: {
            Error.decodeContentFailed(graphQLApiURL, $0)
        }
    }

    static func fetchMetadata(owner: String, repository: String) async throws(Github.Error) -> Metadata {
        struct Response<T: Decodable & Equatable>: Decodable, Equatable {
            var data: T
        }
        return try await fetchResource(Response<Metadata>.self,
                                       query: Metadata.query(owner: owner, repository: repository))
        .data
    }

}


private extension HTTPHeaders {
    func adding<S>(contentsOf other: S) -> Self where S : Sequence, S.Element == (String, String) {
        var headers = self
        headers.add(contentsOf: other)
        return headers
    }
}


// MARK: - Data transfer objects (DTOs)

extension Github {

    struct License: Decodable, Equatable {
        var htmlUrl: String
    }

    struct Readme: Equatable {
        var etag: String?
        var html: String
        var htmlUrl: String
        var imagesToCache: [ImageToCache]

        struct ImageToCache: Equatable {
            var originalUrl: String
            var s3Key: S3Store.Key
        }

        func containsSPIBadge() -> Bool {
            html.contains("https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com")
        }
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
                    fundingLinks {
                      platform
                      url
                    }
                    homepageUrl
                    isArchived
                    isFork
                    parent {
                        url
                    }
                    isInOrganization
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
                        descriptionHTML
                        isDraft
                        publishedAt
                        tagName
                        url
                      }
                    }
                    repositoryTopics(first: 20) {
                      totalCount
                      nodes {
                        topic {
                          name
                        }
                      }
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
            var fundingLinks: [FundingLinkNode]?
            var homepageUrl: String?
            var isArchived: Bool
            // periphery:ignore
            var isFork: Bool
            var parent: Parent?
            var isInOrganization: Bool
            var licenseInfo: LicenseInfo?
            var mergedPullRequests: IssueNodes
            var name: String
            var openIssues: OpenIssues
            var openPullRequests: OpenPullRequests
            var owner: Owner
            var releases: ReleaseNodes
            var repositoryTopics: RepositoryTopicNodes
            var stargazerCount: Int
            // derived properties
            var defaultBranch: String? { defaultBranchRef?.name }
            var lastIssueClosedAt: Date? {
                closedIssues.nodes.map(\.closedAt).sorted().last
            }
            var lastPullRequestClosedAt: Date? {
                (closedPullRequests.nodes + mergedPullRequests.nodes).map(\.closedAt).sorted().last
            }
            var topics: [String] {
                repositoryTopics.nodes.map(\.topic.name)
            }
        }

        struct FundingLinkNode: Codable, Equatable {
            enum Platform: String, Codable {
                case buyMeACoffee = "BUY_ME_A_COFFEE"
                case communityBridge = "COMMUNITY_BRIDGE"
                case customUrl = "CUSTOM"
                case gitHub = "GITHUB"
                case issueHunt = "ISSUEHUNT"
                case koFi = "KO_FI"
                case lfxCrowdfunding = "LFX_CROWDFUNDING"
                case liberapay = "LIBERAPAY"
                case openCollective = "OPEN_COLLECTIVE"
                case otechie = "OTECHIE"
                case patreon = "PATREON"
                case polar = "POLAR"
                case tidelift = "TIDELIFT"
                case thanksDev = "THANKS_DEV"
            }

            var platform: Platform
            var url: String
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
            // periphery:ignore
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
                var descriptionHTML: String?
                var isDraft: Bool
                var publishedAt: Date?
                var tagName: String
                var url: String
            }
        }

        struct RepositoryTopicNodes: Decodable, Equatable {
            var totalCount: Int
            var nodes: [RepositoryTopic]

            struct RepositoryTopic: Decodable, Equatable {
                var topic: Topic

                struct Topic: Decodable, Equatable {
                    var name: String
                }
            }
        }

        struct Parent: Decodable, Equatable {
            var url: String?
        }
    }

}

extension Github {

    static func replaceImagesRequiringCaching(owner: String, repository: String, readme: inout String) -> [Readme.ImageToCache] {
        do {
            let document = try SwiftSoup.parse(readme)
            let imageElements = try document.select("img")

            var imagesToCache: [Readme.ImageToCache] = []
            for imageElement in imageElements.array() {
                if let src = try? imageElement.attr("src"),
                   let srcUrl = URL(string: src),
                   srcUrl.host == "private-user-images.githubusercontent.com",
                   let urlComponents = URLComponents(url: srcUrl, resolvingAgainstBaseURL: false),
                   let jwtParameter = urlComponents.queryItems?.first(where: { $0.name == "jwt" }) {
                    if let jwtValue = jwtParameter.value, jwtValue.isEmpty == false
                    {
                        // Replace the image url and keep a copy of the old one in a `data` attribute
                        let s3Key = try S3Store.Key.readme(owner: owner, repository: repository, imageUrl: src)
                        _ = try imageElement.attr("src", s3Key.objectUrl)
                        _ = try imageElement.attr("data-original-src", src)
                        imagesToCache.append(.init(originalUrl: src, s3Key: s3Key))
                    }
                }
            }

            // Only output modified HTML if there have been changes.
            if imagesToCache.count > 0 {
                readme = try document.outerHtml()
            }
            return imagesToCache
        } catch {
            return []
        }
    }
}
