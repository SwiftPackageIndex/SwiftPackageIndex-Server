@testable import App

import Vapor
import XCTest


class GithubTests: AppTestCase {
    
    func test_getHeader() throws {
        do { // without token
            Current.githubToken = { nil }
            XCTAssertEqual(Github.getHeaders, .init([("User-Agent", "SPI-Server")]))
        }
        do { // with token
            Current.githubToken = { "foobar" }
            XCTAssertEqual(Github.getHeaders, .init([
                ("User-Agent", "SPI-Server"),
                ("Authorization", "token foobar")
            ]))
        }
    }
    
    func test_Github_apiUri() throws {
        do {
            let pkg = Package(url: "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server.git")
            XCTAssertEqual(try Github.apiUri(for: pkg, resource: .repo).string,
                           "https://api.github.com/repos/SwiftPackageIndex/SwiftPackageIndex-Server")
        }
        do {
            let pkg = Package(url: "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server")
            XCTAssertEqual(try Github.apiUri(for: pkg, resource: .repo).string,
                           "https://api.github.com/repos/SwiftPackageIndex/SwiftPackageIndex-Server")
        }
        do {
            let pkg = Package(url: "https://github.com/foo/bar")
            XCTAssertEqual(try Github.apiUri(for: pkg, resource: .issues).string,
                           "https://api.github.com/repos/foo/bar/issues")
        }
        do {
            let pkg = Package(url: "https://github.com/foo/bar")
            XCTAssertEqual(try Github.apiUri(for: pkg, resource: .pulls).string,
                           "https://api.github.com/repos/foo/bar/pulls")
        }
        do {
            let pkg = Package(url: "https://github.com/foo/bar")
            XCTAssertEqual(try Github.apiUri(for: pkg,
                                             resource: .issues,
                                             query: ["sort": "updated",
                                                     "direction": "desc"]).string,
                           "https://api.github.com/repos/foo/bar/issues?direction=desc&sort=updated")
        }
    }
    
    func test_fetchResource_repo() throws {
        // setup
        let pkg = Package(url: "https://github.com/finestructure/Gala")
        let data = try XCTUnwrap(try loadData(for: "github-repository-response.json"))
        let client = MockClient { _, resp in
            resp.status = .ok
            resp.body = makeBody(data)
        }
        let uri = try Github.apiUri(for: pkg, resource: .repo)
        
        // MUT
        let res = try Github.fetchResource(Github.Repo.self, client: client, uri: uri).wait()
        
        // validate
        XCTAssertEqual(res, Github.Repo(defaultBranch: "main",
                                        description: "Gala is a Swift Package Manager project for macOS, iOS, tvOS, and watchOS to help you create SwiftUI preview variants.",
                                        forksCount: 1,
                                        license: .init(key: "mit"),
                                        name: "Gala",
                                        openIssues: 1,
                                        owner: .init(login: "finestructure"),
                                        parent: nil,
                                        stargazersCount: 44))
    }
    
    func test_fetchResource_pulls() throws {
        // setup
        let pkg = Package(url: "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server")
        let data = try XCTUnwrap(try loadData(for: "github-pulls-open-response.json"))
        let client = MockClient { _, resp in
            resp.status = .ok
            resp.body = makeBody(data)
        }
        let uri = try Github.apiUri(for: pkg, resource: .pulls, query: ["state": "open",
                                                                        "sort": "updated",
                                                                        "direction": "desc"])
        
        // MUT
        let res = try Github.fetchResource([Github.Pull].self, client: client, uri: uri).wait()
        
        // validate
        XCTAssertEqual(res.count, 1)
        let first = try XCTUnwrap(res.first)
        XCTAssertEqual(first,
                       .init(url: "https://api.github.com/repos/SwiftPackageIndex/SwiftPackageIndex-Server/pulls/182"))
    }
    
    func test_fetchResource_issues() throws {
        // setup
        let pkg = Package(url: "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server")
        let data = try XCTUnwrap(try loadData(for: "github-issues-closed-response.json"))
        let client = MockClient { _, resp in
            resp.status = .ok
            resp.body = makeBody(data)
        }
        let uri = try Github.apiUri(for: pkg, resource: .issues, query: ["state": "closed",
                                                                         "sort": "closed",
                                                                         "direction": "desc"])
        
        // MUT
        let res = try Github.fetchResource([Github.Issue].self, client: client, uri: uri).wait()
        
        // validate
        XCTAssertEqual(res.count, 30)
        let first = try XCTUnwrap(res.first)
        let last = try XCTUnwrap(res.last)
        XCTAssertEqual(first,
                       .init(closedAt: Date(rfc1123: "Wed, 27 May 2020 09:29:28 GMT"),
                             pullRequest: .init(url: "https://api.github.com/repos/SwiftPackageIndex/SwiftPackageIndex-Server/pulls/181")))
        XCTAssertEqual(last,
                       .init(closedAt: Date(rfc1123: "Sun, 24 May 2020 09:38:26 GMT"),
                             pullRequest: .init(url: "https://api.github.com/repos/SwiftPackageIndex/SwiftPackageIndex-Server/pulls/134")))
    }
    
    func test_fetchMetadata() throws {
        let pkg = Package(url: "https://github.com/finestructure/Gala")
        let client = MockClient { req, resp in
            if req.url.path == "/repos/finestructure/Gala" {
                resp.status = .ok
                let data = try! loadData(for: "github-repository-response.json")
                resp.body = makeBody(data)
            }
            if req.url.path == "/repos/finestructure/Gala/pulls" {
                resp.status = .ok
                let data = try! loadData(for: "github-pulls-open-response.json")
                resp.body = makeBody(data)
            }
            if req.url.path == "/repos/finestructure/Gala/issues" {
                resp.status = .ok
                let data = try! loadData(for: "github-issues-closed-response.json")
                resp.body = makeBody(data)
            }
        }
        
        // MUT
        let md = try Github.fetchMetadata(client: client, package: pkg).wait()
        
        // validate repo
        XCTAssertEqual(md.repo, Github.Repo(defaultBranch: "main",
                                            description: "Gala is a Swift Package Manager project for macOS, iOS, tvOS, and watchOS to help you create SwiftUI preview variants.",
                                            forksCount: 1,
                                            license: .init(key: "mit"),
                                            name: "Gala",
                                            openIssues: 1,
                                            owner: .init(login: "finestructure"),
                                            parent: nil,
                                            stargazersCount: 44))
        // validate issues
        // don't validate issues in detail - it's the same as test_fetchResource_issues above
        XCTAssertEqual(md.issues.count, 30)
        
        // validate PRs
        XCTAssertEqual(md.openPullRequests.count, 1)
        let firstPR = try XCTUnwrap(md.openPullRequests.first)
        XCTAssertEqual(firstPR,
                       .init(url: "https://api.github.com/repos/SwiftPackageIndex/SwiftPackageIndex-Server/pulls/182"))
    }
    
    func test_fetchMetadata_badUrl() throws {
        let pkg = Package(url: "https://foo/bar")
        let client = MockClient { _, resp in
            resp.status = .ok
        }
        XCTAssertThrowsError(try Github.fetchMetadata(client: client, package: pkg).wait()) {
            guard case Github.Error.invalidURI = $0 else {
                XCTFail("unexpected error: \($0.localizedDescription)")
                return
            }
        }
    }
    
    func test_fetchMetadata_badData() throws {
        let pkg = Package(url: "https://github.com/foo/bar")
        let client = MockClient { _, resp in
            resp.status = .ok
            resp.body = makeBody("bad data")
        }
        XCTAssertThrowsError(try Github.fetchMetadata(client: client, package: pkg).wait()) {
            guard case DecodingError.dataCorrupted = $0 else {
                XCTFail("unexpected error: \($0.localizedDescription)")
                return
            }
        }
    }
    
    func test_fetchMetadata_rateLimiting_429() throws {
        // Github doesn't actually send a 429 when you hit the rate limit
        let pkg = Package(url: "https://github.com/foo/bar")
        let client = MockClient { _, resp in
            resp.status = .tooManyRequests
        }
        XCTAssertThrowsError(try Github.fetchMetadata(client: client, package: pkg).wait()) {
            guard case AppError.metadataRequestFailed(nil, .tooManyRequests, _) = $0 else {
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
        XCTAssertThrowsError(try Github.fetchMetadata(client: client, package: pkg).wait()) {
            // validation
            XCTAssertNotNil(reportedError)
            XCTAssertEqual(reportedLevel, .critical)
            guard case AppError.metadataRequestFailed(nil, .tooManyRequests, _) = $0 else {
                XCTFail("unexpected error: \($0.localizedDescription)")
                return
            }
        }
    }
}
