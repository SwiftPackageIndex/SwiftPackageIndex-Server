@testable import App

import PostgresNIO
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

    func test_unique_constraint() throws {
        // Ensure builds are unique over (id, platform, swiftVersion)
        // setup
        let pkg = try savePackage(on: app.db, "1")
        let v1 = try Version(package: pkg)
        try v1.save(on: app.db).wait()
        let v2 = try Version(package: pkg)
        try v2.save(on: app.db).wait()

        // MUT
        // initial save - ok
        try Build(version: v1,
                  platform: .linux("ubuntu-18.04"),
                  status: .ok,
                  swiftVersion: .init(5, 2, 0)).save(on: app.db).wait()
        // different version - ok
        try Build(version: v2,
                  platform: .linux("ubuntu-18.04"),
                  status: .ok,
                  swiftVersion: .init(5, 2, 0)).save(on: app.db).wait()
        // different platform - ok
        try Build(version: v1,
                  platform: .macos("11"),
                  status: .ok,
                  swiftVersion: .init(5, 2, 0)).save(on: app.db).wait()
        // different swiftVersion - ok
        try Build(version: v1,
                  platform: .linux("ubuntu-18.04"),
                  status: .ok,
                  swiftVersion: .init(4, 0, 0)).save(on: app.db).wait()

        // (v1, linx, 5.2.0) - not ok
        XCTAssertThrowsError(
            try Build(version: v1,
                      platform: .linux("ubuntu-18.04"),
                      status: .ok,
                      swiftVersion: .init(5, 2, 0)).save(on: app.db).wait()
        ) {
            XCTAssertEqual(($0 as? PostgresError)?.code, .uniqueViolation)
        }
        
        // validate
        XCTAssertEqual(try Build.query(on: app.db).count().wait(), 4)
    }
    
}
