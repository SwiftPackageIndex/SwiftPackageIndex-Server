@testable import App

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
        let client = MockClient { resp in
            resp.status = .ok
            resp.body = makeBody(data)
        }
        let uri = try Github.apiUri(for: pkg, resource: .repo)

        // MUT
        let res = try Github.fetchResource(Github.Metadata.Repo.self, client: client, uri: uri).wait()

        // validate
        XCTAssertEqual(res, Github.Metadata.Repo(defaultBranch: "master",
                                                 description: "Gala is a Swift Package Manager project for macOS, iOS, tvOS, and watchOS to help you create SwiftUI preview variants.",
                                                 forksCount: 1,
                                                 license: .init(key: "mit"),
                                                 name: "Gala",
                                                 openIssues: 1,
                                                 owner: .init(login: "finestructure"),
                                                 parent: nil,
                                                 stargazersCount: 44))
    }

    func test_fetchResource_issues() throws {
        // setup
        let pkg = Package(url: "https://github.com/finestructure/Gala")
        let data = try XCTUnwrap(try loadData(for: "github-issues-closed-response.json"))
        let client = MockClient { resp in
            resp.status = .ok
            resp.body = makeBody(data)
        }
        let uri = try Github.apiUri(for: pkg, resource: .issues)

        // MUT
        let res = try Github.fetchResource(Github.Metadata.Repo.self, client: client, uri: uri).wait()

        // validate
        XCTAssertEqual(res, Github.Metadata.Repo(defaultBranch: "master",
                                                 description: "Gala is a Swift Package Manager project for macOS, iOS, tvOS, and watchOS to help you create SwiftUI preview variants.",
                                                 forksCount: 1,
                                                 license: .init(key: "mit"),
                                                 name: "Gala",
                                                 openIssues: 1,
                                                 owner: .init(login: "finestructure"),
                                                 parent: nil,
                                                 stargazersCount: 44))
    }

    func test_fetchRepository() throws {
        let pkg = Package(url: "https://github.com/finestructure/Gala")
        let data = try XCTUnwrap(try loadData(for: "github-repository-response.json"))
        let client = MockClient { resp in
            resp.status = .ok
            resp.body = makeBody(data)
        }
        let md = try Github.fetchMetadata(client: client, package: pkg).wait()
        XCTAssertEqual(md.repo, Github.Metadata.Repo(defaultBranch: "master",
                                                     description: "Gala is a Swift Package Manager project for macOS, iOS, tvOS, and watchOS to help you create SwiftUI preview variants.",
                                                     forksCount: 1,
                                                     license: .init(key: "mit"),
                                                     name: "Gala",
                                                     openIssues: 1,
                                                     owner: .init(login: "finestructure"),
                                                     parent: nil,
                                                     stargazersCount: 44))
        XCTFail("test remaining fields")
    }

    func test_fetchRepository_badUrl() throws {
        let pkg = Package(url: "https://foo/bar")
        let client = MockClient { resp in
            resp.status = .ok
        }
        XCTAssertThrowsError(try Github.fetchMetadata(client: client, package: pkg).wait()) {
            guard case AppError.invalidPackageUrl = $0 else {
                XCTFail("unexpected error: \($0.localizedDescription)")
                return
            }
        }
    }

    func test_fetchRepository_badData() throws {
        let pkg = Package(url: "https://github.com/foo/bar")
        let client = MockClient { resp in
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

    func test_fetchRepository_rateLimiting() throws {
        let pkg = Package(url: "https://github.com/foo/bar")
        let client = MockClient { resp in
            resp.status = .tooManyRequests
        }
        XCTAssertThrowsError(try Github.fetchMetadata(client: client, package: pkg).wait()) {
            guard case AppError.metadataRequestFailed(nil, .tooManyRequests, _) = $0 else {
                XCTFail("unexpected error: \($0.localizedDescription)")
                return
            }
        }
    }
}
