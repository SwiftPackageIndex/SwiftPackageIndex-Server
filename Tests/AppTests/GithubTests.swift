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

import Vapor
import XCTest


class GithubTests: AppTestCase {

    func test_parseOwnerName() throws {
        do {
            let res = try Github.parseOwnerName(url: "https://github.com/foo/bar")
            XCTAssertEqual(res.owner, "foo")
            XCTAssertEqual(res.name, "bar")
        }
        do {
            let res = try Github.parseOwnerName(url: "https://github.com/foo/bar.git")
            XCTAssertEqual(res.owner, "foo")
            XCTAssertEqual(res.name, "bar")
        }
        XCTAssertThrowsError(
            try Github.parseOwnerName(url: "https://github.com/foo/bar/baz")
        ) { error in
            XCTAssertEqual(error.localizedDescription,
                           "invalid URL: https://github.com/foo/bar/baz (id: nil)")
        }
    }

    func test_decode_Metadata_null() throws {
        // Ensure missing values don't trip up decoding
        struct Response: Decodable {
            var data: Github.Metadata
        }
        do {
            let data = """
            {"data":{"repository":{"closedIssues":{"nodes":[]},"closedPullRequests":{"nodes":[]},"createdAt":"2019-04-23T09:26:22Z","defaultBranchRef":{"name":"master"},"description":null,"forkCount":0,"isArchived":false,"isFork":false,"licenseInfo":null,"mergedPullRequests":{"nodes":[]},"name":"CRToastSwift","openIssues":{"totalCount":0},"openPullRequests":{"totalCount":0},"owner":{"login":"krugazor","avatarUrl": "https://avatars.githubusercontent.com/u/2742179?u=28d2ccb6a27c975e663738fe86af579ff74203ac&v=4","name": "Nicolas Zinovieff"},"releases":{"nodes":[]},"repositoryTopics":{"totalCount":0,"nodes":[]},"stargazerCount":3,"isInOrganization":false},"rateLimit":{"remaining":4753}}}
            """
            _ = try Github.decoder.decode(Response.self, from: Data(data.utf8))
        }
        do {  // no repository at all (can happen)
            let data = """
                {"data":{"repository":null,"rateLimit":{"remaining":4986}},"errors":[{"type":"NOT_FOUND","path":["repository"],"locations":[{"line":2,"column":3}],"message":"Could not resolve to a Repository with the name 'IBM-Swift/kitura-mustachetemplateengine'."}]}
            """
            _ = try Github.decoder.decode(Response.self, from: Data(data.utf8))
        }
    }

    func test_fetchResource() async throws {
        Current.githubToken = { "secr3t" }
        let client = MockClient { _, resp in
            resp.status = .ok
            resp.body = makeBody("{\"data\":{\"viewer\":{\"login\":\"finestructure\"}}}")
        }
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
        let res = try await Github.fetchResource(Response.self, client: client, query: q)
        XCTAssertEqual(res, Response(data: .init(viewer: .init(login: "finestructure"))))
    }

    func test_fetchMetadata() async throws {
        Current.githubToken = { "secr3t" }
        let data = try XCTUnwrap(try fixtureData(for: "github-graphql-resource.json"))
        let client = MockClient { _, resp in
            resp.status = .ok
            resp.body = makeBody(data)
        }
        let iso8601 = ISO8601DateFormatter()

        // MUT
        let res = try await Github.fetchMetadata(client: client,
                                                 owner: "alamofire",
                                                 repository: "alamofire")

        // validation
        XCTAssertEqual(res.repository?.closedIssues.nodes.first!.closedAt,
                       iso8601.date(from: "2020-07-17T16:27:10Z"))
        XCTAssertEqual(res.repository?.closedPullRequests.nodes.first!.closedAt,
                       iso8601.date(from: "2021-05-28T15:50:17Z"))
        XCTAssertEqual(res.repository?.forkCount, 6727)
        XCTAssertEqual(res.repository?.mergedPullRequests.nodes.first!.closedAt,
                       iso8601.date(from: "2021-06-07T22:47:01Z"))
        XCTAssertEqual(res.repository?.name, "Alamofire")
        XCTAssertEqual(res.repository?.owner.name, "Alamofire")
        XCTAssertEqual(res.repository?.owner.login, "Alamofire")
        XCTAssertEqual(res.repository?.owner.avatarUrl, "https://avatars.githubusercontent.com/u/7774181?v=4")
        XCTAssertEqual(res.repository?.openIssues.totalCount, 30)
        XCTAssertEqual(res.repository?.openPullRequests.totalCount, 6)
        XCTAssertEqual(res.repository?.releases.nodes.count, 20)
        XCTAssertEqual(res.repository?.releases.nodes.first, .some(
            .init(description: "Released on 2020-04-21. All issues associated with this milestone can be found using this [filter](https://github.com/Alamofire/Alamofire/milestone/77?closed=1).\r\n\r\n#### Fixed\r\n- Change in multipart upload creation order.\r\n  - Fixed by [Christian Noon](https://github.com/cnoon) in Pull Request [#3438](https://github.com/Alamofire/Alamofire/pull/3438).\r\n- Typo in Alamofire 5 migration guide.\r\n  - Fixed by [DevYeom](https://github.com/DevYeom) in Pull Request [#3431](https://github.com/Alamofire/Alamofire/pull/3431).",
                  descriptionHTML: "<p>mock descriptionHTML</>",
                  isDraft: false,
                  publishedAt: iso8601.date(from: "2021-04-22T02:50:05Z")!,
                  tagName: "5.4.3",
                  url: "https://github.com/Alamofire/Alamofire/releases/tag/5.4.3")
        ))
        XCTAssertEqual(res.repository?.repositoryTopics.totalCount, 15)
        XCTAssertEqual(res.repository?.repositoryTopics.nodes.first?.topic.name,
                       "networking")
        XCTAssertEqual(res.repository?.stargazerCount, 35831)
        XCTAssertEqual(res.repository?.isInOrganization, true)
        XCTAssertEqual(res.repository?.homepageUrl, "https://swiftpackageindex.com/Alamofire/Alamofire")
        // derived properties
        XCTAssertEqual(res.repository?.lastIssueClosedAt,
                       iso8601.date(from: "2021-06-09T00:59:39Z"))
        // merged date is latest - expect that one to be reported back
        XCTAssertEqual(res.repository?.lastPullRequestClosedAt,
                       iso8601.date(from: "2021-06-07T22:47:01Z"))
    }

    func test_fetchMetadata_badRequest() async throws {
        Current.githubToken = { "secr3t" }
        let client = MockClient { _, resp in
            resp.status = .badRequest
        }

        do {
            _ = try await Github.fetchMetadata(client: client,
                                               owner: "alamofire",
                                               repository: "alamofire")
            XCTFail("expected error to be thrown")
        } catch {
            guard case Github.Error.requestFailed(.badRequest) = error else {
                XCTFail("unexpected error: \(error.localizedDescription)")
                return
            }
        }
    }

    func test_fetchMetadata_badUrl() async throws {
        let pkg = Package(url: "https://foo/bar")
        let client = MockClient { _, resp in
            resp.status = .ok
        }
        do {
            _ = try await Github.fetchMetadata(client: client, packageUrl: pkg.url)
            XCTFail("expected error to be thrown")
        } catch {
            guard case Github.Error.invalidURI = error else {
                XCTFail("unexpected error: \(error.localizedDescription)")
                return
            }
        }
    }

    func test_fetchMetadata_badData() async throws {
        // setup
        Current.githubToken = { "secr3t" }
        let pkg = Package(url: "https://github.com/foo/bar")
        let client = MockClient { _, resp in
            resp.status = .ok
            resp.body = makeBody("bad data")
        }

        // MUT
        do {
            _ = try await Github.fetchMetadata(client: client, packageUrl: pkg.url)
            XCTFail("expected error to be thrown")
        } catch {
            // validation
            guard case DecodingError.dataCorrupted = error else {
                XCTFail("unexpected error: \(error.localizedDescription)")
                return
            }
        }
    }

    func test_fetchMetadata_rateLimiting_429() async throws {
        // Github doesn't actually send a 429 when you hit the rate limit
        // setup
        Current.githubToken = { "secr3t" }
        let pkg = Package(url: "https://github.com/foo/bar")
        let client = MockClient { _, resp in
            resp.status = .tooManyRequests
        }

        // MUT
        do {
            _ = try await Github.fetchMetadata(client: client, packageUrl: pkg.url)
            XCTFail("expected error to be thrown")
        } catch {
            // validation
            guard case Github.Error.requestFailed(.tooManyRequests) = error else {
                XCTFail("unexpected error: \(error.localizedDescription)")
                return
            }
        }
    }

    func test_isRateLimited() throws {
        do {
            let res = ClientResponse(status: .forbidden,
                                     headers: .init([("X-RateLimit-Remaining", "0")]))
            XCTAssertTrue(Github.isRateLimited(res))
        }
        do {
            let res = ClientResponse(status: .forbidden,
                                     headers: .init([("x-ratelimit-remaining", "0")]))
            XCTAssertTrue(Github.isRateLimited(res))
        }
        do {
            let res = ClientResponse(status: .forbidden,
                                     headers: .init([("X-RateLimit-Remaining", "1")]))
            XCTAssertFalse(Github.isRateLimited(res))
        }
        do {
            let res = ClientResponse(status: .forbidden,
                                     headers: .init([("unrelated", "0")]))
            XCTAssertFalse(Github.isRateLimited(res))
        }
        do {
            let res = ClientResponse(status: .ok,
                                     headers: .init([("X-RateLimit-Remaining", "0")]))
            XCTAssertFalse(Github.isRateLimited(res))
        }
    }

    func test_fetchMetadata_rateLimiting_403() async throws {
        // Github sends a 403 and a rate limit remaining header
        //   X-RateLimit-Limit: 60
        //   X-RateLimit-Remaining: 56
        // Ensure we record it as a rate limit error and raise a Rollbar item
        // setup
        Current.githubToken = { "secr3t" }
        let pkg = Package(url: "https://github.com/foo/bar")
        let client = MockClient { _, resp in
            resp.status = .forbidden
            resp.headers.add(name: "X-RateLimit-Remaining", value: "0")
        }
        let logHandler = CapturingLogger()
        Current.setLogger(.init(label: "test", factory: { _ in logHandler }))

        // MUT
        do {
            _ = try await Github.fetchMetadata(client: client, packageUrl: pkg.url)
            XCTFail("expected error to be thrown")
        } catch {
            // validation
            logHandler.logs.withValue { logs in
                XCTAssertEqual(logs, [
                    .init(level: .critical, message: "rate limited while fetching resource Response<Metadata>")
                ])
            }
            guard case Github.Error.requestFailed(.tooManyRequests) = error else {
                XCTFail("unexpected error: \(error.localizedDescription)")
                return
            }
        }
    }

    func test_apiUri() throws {
        let pkg = Package(url: "https://github.com/foo/bar")
        XCTAssertEqual(try Github.apiUri(for: pkg.url, resource: .license).string,
                       "https://api.github.com/repos/foo/bar/license")
        XCTAssertEqual(try Github.apiUri(for: pkg.url, resource: .readme).string,
                       "https://api.github.com/repos/foo/bar/readme")
    }

    func test_fetchLicense() async throws {
        // setup
        Current.githubToken = { "secr3t" }
        let pkg = Package(url: "https://github.com/PSPDFKit/PSPDFKit-SP")
        let data = try XCTUnwrap(try fixtureData(for: "github-license-response.json"))
        let client = MockClient { _, resp in
            resp.status = .ok
            resp.body = makeBody(data)
        }

        // MUT
        let res = await Github.fetchLicense(client: client, packageUrl: pkg.url)

        // validate
        XCTAssertEqual(res?.htmlUrl, "https://github.com/PSPDFKit/PSPDFKit-SP/blob/master/LICENSE")
    }

    func test_fetchLicense_notFound() async throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/761
        // setup
        Current.githubToken = { "secr3t" }
        let pkg = Package(url: "https://github.com/foo/bar")
        let client = MockClient { _, resp in resp.status = .notFound }

        // MUT
        let res = await Github.fetchLicense(client: client, packageUrl: pkg.url)

        // validate
        XCTAssertEqual(res, nil)
    }

    func test_fetchReadme() async throws {
        // setup
        Current.githubToken = { "secr3t" }
        let pkg = Package(url: "https://github.com/daveverwer/leftpad")
        let data = try XCTUnwrap(try fixtureData(for: "github-readme-response.json"))
        let client = MockClient { _, resp in
            resp.status = .ok
            resp.body = makeBody(data)
        }

        // MUT
        let res = await Github.fetchReadme(client: client, packageUrl: pkg.url)

        // validate
        XCTAssertEqual(res?.downloadUrl, "https://raw.githubusercontent.com/daveverwer/LeftPad/master/README.md")
    }

    func test_fetchReadme_notFound() async throws {
        // setup
        Current.githubToken = { "secr3t" }
        let pkg = Package(url: "https://github.com/daveverwer/leftpad")
        let client = MockClient { _, resp in resp.status = .notFound }

        // MUT
        let res = await Github.fetchReadme(client: client, packageUrl: pkg.url)

        // validate
        XCTAssertEqual(res?.downloadUrl, nil)
    }

}
