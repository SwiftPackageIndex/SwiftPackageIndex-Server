@testable import App

import XCTVapor


class BuildTests: AppTestCase {

    func test_save() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        let v = try Version(package: pkg)
        try v.save(on: app.db).wait()
        let b = try Build(version: v,
                          logs: "logs",
                          platform: .linux("ubuntu-18.04"),
                          status: .ok,
                          swiftVersion: .init(5, 2, 0))

        // MUT
        try b.save(on: app.db).wait()

        do {  // validate
            let b = try XCTUnwrap(Build.find(b.id, on: app.db).wait())
            XCTAssertEqual(b.logs, "logs")
            XCTAssertEqual(b.platform, .some(.linux("ubuntu-18.04")))
            XCTAssertEqual(b.$version.id, v.id)
            XCTAssertEqual(b.status, .ok)
        }
    }

    func test_delete_cascade() throws {
        // Ensure deleting a version also deletes the builds
        // setup
        let pkg = try savePackage(on: app.db, "1")
        let v = try Version(package: pkg)
        try v.save(on: app.db).wait()
        let b = try Build(version: v, status: .ok, swiftVersion: .init(5, 2, 0))
        try b.save(on: app.db).wait()
        XCTAssertEqual(try Build.query(on: app.db).count().wait(), 1)

        // MUT
        try v.delete(on: app.db).wait()

        // validate
        XCTAssertEqual(try Build.query(on: app.db).count().wait(), 0)
    }
}
