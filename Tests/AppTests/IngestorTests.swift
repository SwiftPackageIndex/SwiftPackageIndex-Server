@testable import App

import Vapor
import XCTest


class IngestorTests: XCTestCase {
    var app: Application!

    override func setUpWithError() throws {
        app = try setup(.testing)
    }

    override func tearDownWithError() throws {
        app.shutdown()
    }

    func test_basic_ingestion() throws {
        let urls = [
            "https://github.com/finestructure/Gala",
            "https://github.com/finestructure/Rester",
            "https://github.com/finestructure/SwiftPMLibrary-Server"
        ]
        Current.fetchMasterPackageList = { _ in mockFetchMasterPackageList(urls) }

        let packages = try savePackages(on: app.db, urls.compactMap(URL.init(string:)))

        let client = MockClient { resp in
            resp.status = .ok
            resp.body = makeBody("""
            {
            "default_branch": "master",
            "forks_count": 1,
            "stargazers_count": 2,
            }
            """)
        }
        try ingest(client: client, database: app.db, limit: 10).wait()

        let repos = try Repository.query(on: app.db).all().wait()
        XCTAssertEqual(repos.map(\.$package.id), packages.map(\.id))
        repos.forEach {
            XCTAssertNotNil($0.id)
            XCTAssertNotNil($0.$package.id)
            XCTAssertNotNil($0.createdAt)
            XCTAssertNotNil($0.updatedAt)
            XCTAssertEqual($0.defaultBranch, "master")
            XCTAssertEqual($0.forks, 1)
            XCTAssertEqual($0.stars, 2)
        }
    }

}
