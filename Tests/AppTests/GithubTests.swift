@testable import App

import XCTest


class GithubTests: XCTestCase {

    func test_getHeader() throws {
        XCTAssertEqual(Github.getHeaders, .init([("User-Agent", "SPI-Server")]))
        Current.githubToken = { "foobar" }
        XCTAssertEqual(Github.getHeaders, .init([
            ("User-Agent", "SPI-Server"),
            ("Authorization", "token foobar")
        ]))
    }

    func test_Github_apiUri() throws {
        do {
            let pkg = Package(url: "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server.git".url)
            XCTAssertEqual(try Github.apiUri(for: pkg).string,
                           "https://api.github.com/repos/SwiftPackageIndex/SwiftPackageIndex-Server")
        }
        do {
            let pkg = Package(url: "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server".url)
            XCTAssertEqual(try Github.apiUri(for: pkg).string,
                           "https://api.github.com/repos/SwiftPackageIndex/SwiftPackageIndex-Server")
        }
    }

    func test_fetchRepository() throws {
        // TODO: add scenarios
        // - happy path
        // - decoding error
        // - rate limiting
        // - general error

        // To mock use:
        // TODO: mock out Github.fetchRepository and test Github separately
        // while using the Github mock here, for higher level tests
        //        let client = MockClient { resp in
        //            resp.status = .ok
        //            resp.body = makeBody("""
        //            {
        //            "default_branch": "master",
        //            "forks_count": 1,
        //            "stargazers_count": 2,
        //            }
        //            """)
        //        }
        //        try Github.fetchRepository(client: client, package: pkg).wait()
    }

}
