import Foundation
import Fluent

@testable import App

import XCTVapor


final class AppTests: XCTestCase {
    func testHelloWorld() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        try app.test(.GET, "hello") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "Hello, world!")
        }
    }

    func test_Package_encode() throws {
        let p = Package(id: UUID(), url: URL(string: "https://github.com/finestructure/Arena")!)
        p.lastCommitAt = Date()
        let data = try JSONEncoder().encode(p)
        XCTAssertTrue(!data.isEmpty)
    }

    func test_Package_decode() throws {
        let timestamp: TimeInterval = 609426189  // Apr 24, 2020, just before 13:00 UTC
                                                 // Date.timeIntervalSinceReferenceDate
        let json = """
        {
            "id": "CAFECAFE-CAFE-CAFE-CAFE-CAFECAFECAFE",
            "url": "https://github.com/finestructure/Arena",
            "lastCommitAt": \(timestamp)
        }
        """
        let p = try JSONDecoder().decode(Package.self, from: Data(json.utf8))
        XCTAssertEqual(p.id?.uuidString, "CAFECAFE-CAFE-CAFE-CAFE-CAFECAFECAFE")
        XCTAssertEqual(p.url, "https://github.com/finestructure/Arena")
        XCTAssertEqual(p.lastCommitAt?.description, "2020-04-24 13:03:09 +0000")
    }

    func test_Package_filter_by_url() throws {
        let app = try setup(.testing)
        defer { app.shutdown() }

        try ["https://foo.com/1", "https://foo.com/2"].forEach {
            try Package(url: $0.url).save(on: app.db).wait()
        }
        let res = try Package.query(on: app.db).filter(by: "https://foo.com/1".url).all().wait()
        XCTAssertEqual(res.map(\.url), ["https://foo.com/1"])
    }
}


func setup(_ environment: Environment, resetDb: Bool = true) throws -> Application {
    let app = Application(.testing)
    try configure(app)
    if resetDb {
        try app.autoRevert().wait()
        try app.autoMigrate().wait()
    }
    return app
}


extension String {
    var url: URL {
        URL(string: self)!
    }
}
