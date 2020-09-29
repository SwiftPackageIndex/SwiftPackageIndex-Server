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

    func test_fetchResource() throws {
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
        let res = try Github.fetchResource(Response.self, client: client, query: q).wait()
        XCTAssertEqual(res, Response(data: .init(viewer: .init(login: "finestructure"))))
    }

    func test_fetchMetadata() throws {
        Current.githubToken = { "secr3t" }
        let data = try XCTUnwrap(try loadData(for: "github-graphql-resource.json"))
        let client = MockClient { _, resp in
            resp.status = .ok
            resp.body = makeBody(data)
        }

        // MUT
        let res = try Github.fetchMetadata(client: client,
                                           owner: "alamofire",
                                           repository: "alamofire").wait()

        // validation
        XCTAssertEqual(res.repository.closedPullRequests.edges.first!.node.closedAt,
                       Date(timeIntervalSince1970: 1597345808.0))  // "2020-08-13T19:10:08Z"
        XCTAssertEqual(res.repository.createdAt,
                       Date(timeIntervalSince1970: 1406786179.0))  // "2014-07-31T05:56:19Z"
        XCTAssertEqual(res.repository.forkCount, 6384)
        XCTAssertEqual(res.repository.mergedPullRequests.edges.first!.node.closedAt,
                       Date(timeIntervalSince1970: 1600713705.0))  // "2020-09-21T18:41:45Z"
        XCTAssertEqual(res.repository.name, "Alamofire")
        XCTAssertEqual(res.repository.openIssues.totalCount, 32)
        XCTAssertEqual(res.repository.openPullRequests.totalCount, 7)
        XCTAssertEqual(res.rateLimit.remaining, 4981)
        // derived properties
        XCTAssertEqual(res.repository.lastIssueClosedAt,
                       Date(timeIntervalSince1970: 1601252524.0))  // "2020-09-28T00:22:04Z"
        // merged date is latest - expect that one to be reported back
        XCTAssertEqual(res.repository.lastPullRequestClosedAt,
                       Date(timeIntervalSince1970: 1600713705.0))  // "2020-09-21T18:41:45Z"
    }

    func test_fetchMetadata_badRequest() throws {
        Current.githubToken = { "secr3t" }
        let client = MockClient { _, resp in
            resp.status = .badRequest
        }

        XCTAssertThrowsError(
            try Github.fetchMetadata(client: client,
                                     owner: "alamofire",
                                     repository: "alamofire").wait()
        ) {
            guard case Github.Error.requestFailed(.badRequest) = $0 else {
                XCTFail("unexpected error: \($0.localizedDescription)")
                return
            }
        }
    }

    func test_fetchMetadata_badUrl() throws {
        let pkg = Package(url: "https://foo/bar")
        let client = MockClient { _, resp in
            resp.status = .ok
        }
        XCTAssertThrowsError(try Github.new_fetchMetadata(client: client, package: pkg).wait()) {
            guard case Github.Error.invalidURI = $0 else {
                XCTFail("unexpected error: \($0.localizedDescription)")
                return
            }
        }
    }
    
    func test_fetchMetadata_badData() throws {
        // setup
        Current.githubToken = { "secr3t" }
        let pkg = Package(url: "https://github.com/foo/bar")
        let client = MockClient { _, resp in
            resp.status = .ok
            resp.body = makeBody("bad data")
        }

        // MUT
        XCTAssertThrowsError(try Github.new_fetchMetadata(client: client, package: pkg).wait()) {
            // validation
            guard case DecodingError.dataCorrupted = $0 else {
                XCTFail("unexpected error: \($0.localizedDescription)")
                return
            }
        }
    }
    
    func test_fetchMetadata_rateLimiting_429() throws {
        // Github doesn't actually send a 429 when you hit the rate limit
        // setup
        Current.githubToken = { "secr3t" }
        let pkg = Package(url: "https://github.com/foo/bar")
        let client = MockClient { _, resp in
            resp.status = .tooManyRequests
        }

        // MUT
        XCTAssertThrowsError(try Github.new_fetchMetadata(client: client, package: pkg).wait()) {
            // validation
            guard case Github.Error.requestFailed(.tooManyRequests) = $0 else {
                XCTFail("unexpected error: \($0.localizedDescription)")
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
    
    func test_fetchMetadata_rateLimiting_403() throws {
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
        var reportedLevel: AppError.Level? = nil
        var reportedError: Error? = nil
        Current.reportError = { _, level, error in
            reportedLevel = level
            reportedError = error
            return .just(value: ())
        }
        
        // MUT
        XCTAssertThrowsError(try Github.new_fetchMetadata(client: client, package: pkg).wait()) {
            // validation
            XCTAssertNotNil(reportedError)
            XCTAssertEqual(reportedLevel, .critical)
            guard case Github.Error.requestFailed(.tooManyRequests) = $0 else {
                XCTFail("unexpected error: \($0.localizedDescription)")
                return
            }
        }
    }

}
