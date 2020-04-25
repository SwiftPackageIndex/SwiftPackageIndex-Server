@testable import App

import XCTVapor


final class ModelTests: XCTestCase {
    func test_package_relationship() throws {
        let app = try setup(.testing)
        defer { app.shutdown() }

        let pkg = Package(url: "p1".url)
        try pkg.save(on: app.db).wait()
        let repo = try Repository(package: pkg)
        try repo.save(on: app.db).wait()
        // test some ways to resolve the relationship
        XCTAssertEqual(repo.$package.id, pkg.id)
        XCTAssertEqual(try repo.$package.get(on: app.db).wait().url, "p1")

        // ensure one-to-one is in place
        do {
            let repo = try Repository(package: pkg)
            XCTAssertThrowsError(try repo.save(on: app.db).wait())
            XCTAssertEqual(try Repository.query(on: app.db).all().wait().count, 1)
        }
    }

    func test_forkedFrom_relationship() throws {
        let app = try setup(.testing)
        defer { app.shutdown() }
        XCTAssert(false, "implement me")
    }
}
