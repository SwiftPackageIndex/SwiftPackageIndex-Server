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

@testable import App

import Dependencies
import Logging
import S3Store
import SwiftSoup
import Testing
import Vapor


extension AllTests.GithubTests {

    @Test func parseOwnerName() throws {
        do {
            let res = try Github.parseOwnerName(url: "https://github.com/foo/bar")
            #expect(res.owner == "foo")
            #expect(res.name == "bar")
        }
        do {
            let res = try Github.parseOwnerName(url: "https://github.com/foo/bar.git")
            #expect(res.owner == "foo")
            #expect(res.name == "bar")
        }
        do {
            _ = try Github.parseOwnerName(url: "https://github.com/foo/bar/baz")
            Issue.record("Expected error")
        } catch let Github.Error.invalidURL(url) {
            #expect(url == "https://github.com/foo/bar/baz")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func decode_Metadata_null() throws {
        // Ensure missing values don't trip up decoding
        struct Response: Decodable {
            var data: Github.Metadata
        }
        do {
            let data = """
            {
                "data": {
                "repository": {
                    "closedIssues": { "nodes": [] },
                    "closedPullRequests": { "nodes": [] },
                    "createdAt": "2019-04-23T09:26:22Z",
                    "defaultBranchRef": { "name": "master" },
                    "description": null,
                    "forkCount": 0,
                    "isArchived": false,
                    "isFork": false,
                    "licenseInfo": null,
                    "mergedPullRequests": { "nodes": [] },
                    "name": "CRToastSwift",
                    "openIssues": { "totalCount": 0 },
                    "openPullRequests": { "totalCount": 0 },
                    "owner": {
                        "login": "krugazor",
                        "avatarUrl": "https://avatars.githubusercontent.com/u/2742179?u=28d2ccb6a27c975e663738fe86af579ff74203ac&v=4",
                        "name": "Nicolas Zinovieff"
                    },
                    "releases": { "nodes": [] },
                    "repositoryTopics": { "totalCount": 0, "nodes": [] },
                    "stargazerCount": 3,
                    "isInOrganization": false
                    },
                    "rateLimit": { "remaining": 4753 }
                }
            }
            """
            _ = try Github.decoder.decode(Response.self, from: Data(data.utf8))
        }
        do {  // no repository at all (can happen)
            let data = """
            {
                "data": { "repository": null, "rateLimit": { "remaining": 4986 } },
                "errors": [
                    {
                        "type": "NOT_FOUND",
                        "path": ["repository"],
                        "locations": [{ "line": 2, "column": 3 }],
                        "message": "Could not resolve to a Repository with the name 'IBM-Swift/kitura-mustachetemplateengine'."
                    }
                ]
            }
            """
            _ = try Github.decoder.decode(Response.self, from: Data(data.utf8))
        }
    }

    @Test func fetchResource() async throws {
        struct Response: Decodable, Equatable {
            var data: Data
            struct Data: Decodable, Equatable {
                var viewer: Viewer
            }
            struct Viewer: Decodable, Equatable {
                var login: String
            }
        }
        let q = Github.GraphQLQuery(query: "query { viewer { login } }")

        try await withDependencies {
            $0.github.token = { "secr3t" }
            $0.httpClient.post = { @Sendable _, _, _ in
                .ok(body: #"{"data":{"viewer":{"login":"finestructure"}}}"#)
            }
        } operation: {
            let res = try await Github.fetchResource(Response.self, query: q)
            #expect(res == Response(data: .init(viewer: .init(login: "finestructure"))))
        }
    }

    @Test func fetchMetadata() async throws {
        let iso8601 = ISO8601DateFormatter()

        try await withDependencies {
            $0.github.token = { "secr3t" }
            $0.httpClient.post = { @Sendable _, _, _ in
                try .ok(fixture: "github-graphql-resource.json")
            }
        } operation: {
            // MUT
            let res = try await Github.fetchMetadata(owner: "alamofire",
                                                     repository: "alamofire")

            // validation
            #expect(res.repository?.closedIssues.nodes.first!.closedAt == iso8601.date(from: "2020-07-17T16:27:10Z"))
            #expect(res.repository?.closedPullRequests.nodes.first!.closedAt == iso8601.date(from: "2021-05-28T15:50:17Z"))
            #expect(res.repository?.forkCount == 6727)
            #expect(res.repository?.fundingLinks == [
                .init(platform: .gitHub, url: "https://github.com/Alamofire"),
                .init(platform: .lfxCrowdfunding, url: "https://crowdfunding.lfx.linuxfoundation.org/projects/alamofire"),
            ])
            #expect(res.repository?.mergedPullRequests.nodes.first!.closedAt == iso8601.date(from: "2021-06-07T22:47:01Z"))
            #expect(res.repository?.name == "Alamofire")
            #expect(res.repository?.owner.name == "Alamofire")
            #expect(res.repository?.owner.login == "Alamofire")
            #expect(res.repository?.owner.avatarUrl == "https://avatars.githubusercontent.com/u/7774181?v=4")
            #expect(res.repository?.openIssues.totalCount == 30)
            #expect(res.repository?.openPullRequests.totalCount == 6)
            #expect(res.repository?.releases.nodes.count == 20)
            #expect(res.repository?.releases.nodes.first == .some(
                .init(description: "Released on 2020-04-21. All issues associated with this milestone can be found using this [filter](https://github.com/Alamofire/Alamofire/milestone/77?closed=1).\r\n\r\n#### Fixed\r\n- Change in multipart upload creation order.\r\n  - Fixed by [Christian Noon](https://github.com/cnoon) in Pull Request [#3438](https://github.com/Alamofire/Alamofire/pull/3438).\r\n- Typo in Alamofire 5 migration guide.\r\n  - Fixed by [DevYeom](https://github.com/DevYeom) in Pull Request [#3431](https://github.com/Alamofire/Alamofire/pull/3431).",
                      descriptionHTML: "<p>mock descriptionHTML</>",
                      isDraft: false,
                      publishedAt: iso8601.date(from: "2021-04-22T02:50:05Z")!,
                      tagName: "5.4.3",
                      url: "https://github.com/Alamofire/Alamofire/releases/tag/5.4.3")
            ))
            #expect(res.repository?.repositoryTopics.totalCount == 15)
            #expect(res.repository?.repositoryTopics.nodes.first?.topic.name == "networking")
            #expect(res.repository?.stargazerCount == 35831)
            #expect(res.repository?.isInOrganization == true)
            #expect(res.repository?.homepageUrl == "https://swiftpackageindex.com/Alamofire/Alamofire")
            // derived properties
            #expect(res.repository?.lastIssueClosedAt == iso8601.date(from: "2021-06-09T00:59:39Z"))
            // merged date is latest - expect that one to be reported back
            #expect(res.repository?.lastPullRequestClosedAt == iso8601.date(from: "2021-06-07T22:47:01Z"))
        }
    }

    @Test func fetchMetadata_badRequest() async throws {
        await withDependencies {
            $0.github.token = { "secr3t" }
            $0.httpClient.post = { @Sendable _, _, _ in .badRequest }
            $0.logger = .noop
        } operation: {
            do {
                _ = try await Github.fetchMetadata(owner: "alamofire",
                                                   repository: "alamofire")
                Issue.record("expected error to be thrown")
            } catch {
                guard case Github.Error.requestFailed(.badRequest) = error else {
                    Issue.record("unexpected error: \(error.localizedDescription)")
                    return
                }
            }
        }
    }

    @Test func fetchMetadata_badData() async throws {
        await withDependencies {
            $0.github.token = { "secr3t" }
            $0.httpClient.post = { @Sendable _, _, _ in .ok(body: "bad data") }
        } operation: {
            // MUT
            do {
                _ = try await Github.fetchMetadata(owner: "foo", repository: "bar")
                Issue.record("expected error to be thrown")
            } catch let Github.Error.decodeContentFailed(uri, error) {
                // validation
                #expect(uri == "https://api.github.com/graphql")
                guard case DecodingError.dataCorrupted = error else {
                    Issue.record("unexpected error: \(error.localizedDescription)")
                    return
                }
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    @Test func fetchMetadata_rateLimiting_429() async throws {
        // Github doesn't actually send a 429 when you hit the rate limit
        await withDependencies {
            $0.github.token = { "secr3t" }
            $0.httpClient.post = { @Sendable _, _, _ in .tooManyRequests }
            $0.logger = .noop
        } operation: {
            // MUT
            do {
                _ = try await Github.fetchMetadata(owner: "foo", repository: "bar")
                Issue.record("expected error to be thrown")
            } catch {
                // validation
                guard case Github.Error.requestFailed(.tooManyRequests) = error else {
                    Issue.record("unexpected error: \(error.localizedDescription)")
                    return
                }
            }
        }
    }

    @Test func isRateLimited() throws {
        do {
            let res = HTTPClient.Response(status: .forbidden,
                                          headers: .init([("X-RateLimit-Remaining", "0")]))
            #expect(Github.isRateLimited(res))
        }
        do {
            let res = HTTPClient.Response(status: .forbidden,
                                          headers: .init([("x-ratelimit-remaining", "0")]))
            #expect(Github.isRateLimited(res))
        }
        do {
            let res = HTTPClient.Response(status: .forbidden,
                                          headers: .init([("X-RateLimit-Remaining", "1")]))
            #expect(!Github.isRateLimited(res))
        }
        do {
            let res = HTTPClient.Response(status: .forbidden,
                                          headers: .init([("unrelated", "0")]))
            #expect(!Github.isRateLimited(res))
        }
        do {
            let res = HTTPClient.Response(status: .ok,
                                          headers: .init([("X-RateLimit-Remaining", "0")]))
            #expect(!Github.isRateLimited(res))
        }
    }

    @Test func fetchMetadata_rateLimiting_403() async throws {
        // Github sends a 403 and a rate limit remaining header
        //   X-RateLimit-Limit: 60
        //   X-RateLimit-Remaining: 56
        // Ensure we record it as a rate limit error
        let capturingLogger = CapturingLogger()
        await withDependencies {
            $0.github.token = { "secr3t" }
            $0.httpClient.post = { @Sendable _, _, _ in
                    .init(status: .forbidden, headers: ["X-RateLimit-Remaining": "0"])
            }
            $0.logger = .testLogger(capturingLogger)
        } operation: {
            // MUT
            do {
                _ = try await Github.fetchMetadata(owner: "foo", repository: "bar")
                Issue.record("expected error to be thrown")
            } catch {
                // validation
                capturingLogger.logs.withValue { logs in
                    #expect(logs == [
                        .init(level: .critical, message: "rate limited while fetching resource Response<Metadata>")
                    ])
                }
                guard case Github.Error.requestFailed(.tooManyRequests) = error else {
                    Issue.record("unexpected error: \(error.localizedDescription)")
                    return
                }
            }
        }
    }

    @Test func apiURL() throws {
        #expect(Github.apiURL(owner: "foo", repository: "bar", resource: .license) == "https://api.github.com/repos/foo/bar/license")
        #expect(Github.apiURL(owner: "foo", repository: "bar", resource: .readme) == "https://api.github.com/repos/foo/bar/readme")
    }

    @Test func fetchLicense() async throws {
        await withDependencies {
            $0.github.token = { "secr3t" }
            $0.httpClient.get = { @Sendable _, _ in
                try .ok(fixture: "github-license-response.json")
            }
        } operation: {
            // MUT
            let res = await Github.fetchLicense(owner: "PSPDFKit", repository: "PSPDFKit-SP")

            // validate
            #expect(res?.htmlUrl == "https://github.com/PSPDFKit/PSPDFKit-SP/blob/master/LICENSE")
        }
    }

    @Test func fetchLicense_notFound() async throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/761
        await withDependencies {
            $0.github.token = { "secr3t" }
            $0.httpClient.get = { @Sendable _, _ in .notFound }
        } operation: {
            // MUT
            let res = await Github.fetchLicense(owner: "foo", repository: "bar")

            // validate
            #expect(res == nil)
        }
    }

    @Test func fetchReadme() async throws {
        let requestCount = QueueIsolated(0)
        await withDependencies {
            $0.github.token = { "secr3t" }
            $0.httpClient.get = { @Sendable _, headers in
                requestCount.increment()
                switch headers[.accept] {
                    case ["application/vnd.github.html+json"]:
                        return .ok(body: "readme html", headers: ["ETag": "etag"])
                    case []:
                        struct Response: Encodable {
                            var htmlUrl: String
                        }
                        return try .ok(jsonEncode: Response(htmlUrl: "readme url"))
                    default:
                        Issue.record("unexpected accept header")
                }
                enum Error: Swift.Error { case unexpectedCodePath }
                throw Error.unexpectedCodePath
            }
        } operation: {
            // MUT
            let res = await Github.fetchReadme(owner: "foo", repository: "bar")

            // validate
            #expect(requestCount.value == 2)
            #expect(
                res == .init(etag: "etag",
                      html: "readme html",
                      htmlUrl: "readme url",
                      imagesToCache: [])
            )
        }
    }

    @Test func fetchReadme_notFound() async throws {
        await withDependencies {
            $0.github.token = { "secr3t" }
            $0.httpClient.get = { @Sendable _, headers in .notFound }
            $0.logger = .noop
        } operation: {
            // MUT
            let res = await Github.fetchReadme(owner: "foo", repository: "bar")

            // validate
            #expect(res == nil)
        }
    }

    @Test func extractImagesRequiringCaching() async throws {
        try withDependencies {
            $0.environment.awsReadmeBucket = { "awsReadmeBucket" }
        } operation: {
            var readme = """
        <html>
        <head></head>
        <body>
            <img src="https://private-user-images.githubusercontent.com/with-jwt.jpg?jwt=some-jwt" />
            <img src="https://private-user-images.githubusercontent.com/without-jwt.jpg" />
            <img src="https://raw.githubusercontent.com/raw-image.png" />
            <img src="https://github.com/example/repo/branch/assets/example.png" />
            <img src="https://example.com/other-domain.jpg" />
        </body>
        </html>
        """

            // MUT
            let images = Github.replaceImagesRequiringCaching(owner: "owner", repository: "repo", readme: &readme)

            #expect(images == [
                .init(originalUrl: "https://private-user-images.githubusercontent.com/with-jwt.jpg?jwt=some-jwt",
                      s3Key: S3Store.Key.init(bucket: "awsReadmeBucket", path: "owner/repo/with-jwt.jpg"))
            ])

            let document = try SwiftSoup.parse(readme)
            let imageElements = try document.select("img").array()

            #expect(try imageElements.map { try $0.attr("src") } == [
                "https://awsReadmeBucket.s3.us-east-2.amazonaws.com/owner/repo/with-jwt.jpg",
                "https://private-user-images.githubusercontent.com/without-jwt.jpg",
                "https://raw.githubusercontent.com/raw-image.png",
                "https://github.com/example/repo/branch/assets/example.png",
                "https://example.com/other-domain.jpg"
            ])

            #expect(try imageElements.map { try $0.attr("data-original-src") } == [
                "https://private-user-images.githubusercontent.com/with-jwt.jpg?jwt=some-jwt",
                "", "", "", "" // This attribute only gets added to images that will be cached.
            ])
        }
    }

    @Test func extractImagesRequiringCaching_noUnnecessaryChanges() async throws {
        withDependencies {
            $0.environment.awsReadmeBucket = { "awsReadmeBucket" }
        } operation: {
            var readme = """
        <html>
        <head></head>
        <body>
          <p>There's nothing here that <code>extractImagesRequiringCaching</code> needs to modify, so
             the HTML should be completely unmodified. We should only replace the README with a newly
             parsed version if we need to.</p>
        </body>
        </html>
        """

            let originalReadme = readme

            // MUT
            let images = Github.replaceImagesRequiringCaching(owner: "owner", repository: "repo", readme: &readme)

            // Checks
            #expect(originalReadme == readme)
            #expect(images == [])
        }
    }

    @Test func Readme_containsSPIBadge() throws {
        do {
            let html = """
            <div id="readme" class="md" data-path="README.md"><article class="markdown-body entry-content container-lg" itemprop="text"><p dir="auto"><a href="https://swiftpackageindex.com/SwiftPackageIndex/SemanticVersion" rel="nofollow"><img src="https://camo.githubusercontent.com/f84b802d1cb9fa24a95e7dedb833a3bba4021eb194ff617d1ad1c8b42e177e04/68747470733a2f2f696d672e736869656c64732e696f2f656e64706f696e743f75726c3d687474707325334125324625324673776966747061636b616765696e6465782e636f6d2532466170692532467061636b6167657325324653776966745061636b616765496e64657825324653656d616e74696356657273696f6e25324662616467652533467479706525334473776966742d76657273696f6e73" alt="" data-canonical-src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FSwiftPackageIndex%2FSemanticVersion%2Fbadge%3Ftype%3Dswift-versions" style="max-width: 100%;"></a>
            <a href="https://swiftpackageindex.com/SwiftPackageIndex/SemanticVersion" rel="nofollow"><img src="https://camo.githubusercontent.com/8e31075beb5ea5a79a03fa0db50fe102b74e9804f5bcff1f1f0dc698b9255ca3/68747470733a2f2f696d672e736869656c64732e696f2f656e64706f696e743f75726c3d687474707325334125324625324673776966747061636b616765696e6465782e636f6d2532466170692532467061636b6167657325324653776966745061636b616765496e64657825324653656d616e74696356657273696f6e253246626164676525334674797065253344706c6174666f726d73" alt="" data-canonical-src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FSwiftPackageIndex%2FSemanticVersion%2Fbadge%3Ftype%3Dplatforms" style="max-width: 100%;"></a></p>
            <div class="markdown-heading" dir="auto"><h1 class="heading-element" dir="auto">🏷 SemanticVersion</h1><a id="user-content--semanticversion" class="anchor" aria-label="Permalink: 🏷 SemanticVersion" href="#-semanticversion"><svg class="octicon octicon-link" viewBox="0 0 16 16" version="1.1" width="16" height="16" aria-hidden="true"><path d="m7.775 3.275 1.25-1.25a3.5 3.5 0 1 1 4.95 4.95l-2.5 2.5a3.5 3.5 0 0 1-4.95 0 .751.751 0 0 1 .018-1.042.751.751 0 0 1 1.042-.018 1.998 1.998 0 0 0 2.83 0l2.5-2.5a2.002 2.002 0 0 0-2.83-2.83l-1.25 1.25a.751.751 0 0 1-1.042-.018.751.751 0 0 1-.018-1.042Zm-4.69 9.64a1.998 1.998 0 0 0 2.83 0l1.25-1.25a.751.751 0 0 1 1.042.018.751.751 0 0 1 .018 1.042l-1.25 1.25a3.5 3.5 0 1 1-4.95-4.95l2.5-2.5a3.5 3.5 0 0 1 4.95 0 .751.751 0 0 1-.018 1.042.751.751 0 0 1-1.042.018 1.998 1.998 0 0 0-2.83 0l-2.5 2.5a1.998 1.998 0 0 0 0 2.83Z"></path></svg></a></div>
            """
            let readme = Github.Readme(html: html, htmlUrl: "url", imagesToCache: [])
            #expect(readme.containsSPIBadge())
        }
        do {
            let readme = Github.Readme(html: "some html", htmlUrl: "url", imagesToCache: [])
            #expect(!readme.containsSPIBadge())
        }
    }

}
