@testable import App

import XCTVapor


class VersionTests: XCTestCase {

    func test_Version_save() throws {
        // setup
        let app = try setup(.testing, resetDb: true)
        defer { app.shutdown() }
        
        let pkg = try savePackage(on: app.db, "1")
        let v = try Version(package: pkg)

        // MUT - save to create
        try v.save(on: app.db).wait()

        // validation
        XCTAssertEqual(v.$package.id, pkg.id)

        v.commit = "commit"
        v.reference = .branch("branch")
        v.packageName = "pname"
        v.supportedPlatforms = [.ios("13"), .macos("10.15")]
        v.swiftVersions = ["4.0", "5.2"].asSwiftVersions

        // MUT - save to update
        try v.save(on: app.db).wait()

        do {  // validation
            let v = try XCTUnwrap(Version.find(v.id, on: app.db).wait())
            XCTAssertEqual(v.commit, "commit")
            XCTAssertEqual(v.reference, .branch("branch"))
            XCTAssertEqual(v.packageName, "pname")
            XCTAssertEqual(v.supportedPlatforms, [.ios("13"), .macos("10.15")])
            XCTAssertEqual(v.swiftVersions, ["4.0", "5.2"].asSwiftVersions)
        }
    }

    func test_Version_empty_array_error() throws {
        // Test for
        // invalid field: swift_versions type: Array<SemVer> error: Unexpected data type: JSONB[]. Expected array.
        // Fix is .sql(.default("{}"))
        // setup
        let app = try setup(.testing, resetDb: true)
        defer { app.shutdown() }
        let pkg = try savePackage(on: app.db, "1")
        let v = try Version(package: pkg)

        // MUT
        try v.save(on: app.db).wait()

        // validation
        _ = try XCTUnwrap(Version.find(v.id, on: app.db).wait())
    }

    func test_delete_cascade() throws {
        // delete package must delete version
        // setup
        let app = try setup(.testing, resetDb: true)
        defer { app.shutdown() }

        let pkg = Package(id: UUID(), url: "1")
        let ver = try Version(id: UUID(), package: pkg)
        try pkg.save(on: app.db).wait()
        try ver.save(on: app.db).wait()

        XCTAssertEqual(try Package.query(on: app.db).count().wait(), 1)
        XCTAssertEqual(try Version.query(on: app.db).count().wait(), 1)

        // MUT
        try pkg.delete(on: app.db).wait()

        // version should be deleted
        XCTAssertEqual(try Package.query(on: app.db).count().wait(), 0)
        XCTAssertEqual(try Version.query(on: app.db).count().wait(), 0)
    }

    func test_supportsMajorSwiftVersion() throws {
        XCTAssert(Version.supportsMajorSwiftVersion(5, value: "5".asSwiftVersion))
        XCTAssert(Version.supportsMajorSwiftVersion(5, value: "5.0".asSwiftVersion))
        XCTAssert(Version.supportsMajorSwiftVersion(5, value: "5.1".asSwiftVersion))
        XCTAssert(Version.supportsMajorSwiftVersion(4, value: "5".asSwiftVersion))
        XCTAssertFalse(Version.supportsMajorSwiftVersion(5, value: "4".asSwiftVersion))
        XCTAssertFalse(Version.supportsMajorSwiftVersion(5, value: "4.0".asSwiftVersion))
    }

    func test_supportsMajorSwiftVersion_values() throws {
        XCTAssert(Version.supportsMajorSwiftVersion(5, values: ["5"].asSwiftVersions))
        XCTAssertFalse(Version.supportsMajorSwiftVersion(5, values: ["4"].asSwiftVersions))
        XCTAssert(Version.supportsMajorSwiftVersion(5, values: ["5.2", "4", "3.0", "3.1", "2"].asSwiftVersions))
        XCTAssertFalse(Version.supportsMajorSwiftVersion(5, values: ["4", "3.0", "3.1", "2"].asSwiftVersions))
        XCTAssert(Version.supportsMajorSwiftVersion(4, values: ["4", "3.0", "3.1", "2"].asSwiftVersions))
    }

}
