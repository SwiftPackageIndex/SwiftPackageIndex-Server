@testable import App

import XCTVapor


class VersionTests: AppTestCase {

    func test_Version_save() throws {
        let pkg = try savePackage(on: app.db, "1")
        let v = try Version(package: pkg)
        try v.save(on: app.db).wait()
        XCTAssertEqual(v.$package.id, pkg.id)
        v.commit = "commit"
        v.reference = .branch("branch")
        v.packageName = "pname"
        v.supportedPlatforms = [.ios("13"), .macos("10.15")]
        v.swiftVersions = ["4.0", "5.2"].sw
        try v.save(on: app.db).wait()
        do {
            let v = try XCTUnwrap(Version.find(v.id, on: app.db).wait())
            XCTAssertEqual(v.commit, "commit")
            XCTAssertEqual(v.reference, .branch("branch"))
            XCTAssertEqual(v.packageName, "pname")
            XCTAssertEqual(v.supportedPlatforms, [.ios("13"), .macos("10.15")])
            XCTAssertEqual(v.swiftVersions, ["4.0", "5.2"].sw)
        }
    }

    func test_Version_empty_array_error() throws {
        // Test for
        // invalid field: swift_versions type: Array<SemVer> error: Unexpected data type: JSONB[]. Expected array.
        // Fix is .sql(.default("{}"))
        let pkg = try savePackage(on: app.db, "1")
        let v = try Version(package: pkg)
        try v.save(on: app.db).wait()
        _ = try XCTUnwrap(Version.find(v.id, on: app.db).wait())
    }

    func test_delete_cascade() throws {
        // delete package must delete version
        let pkg = Package(id: UUID(), url: "1", status: .none)
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
        XCTAssert(Version.supportsMajorSwiftVersion(5, value: "5".sw))
        XCTAssert(Version.supportsMajorSwiftVersion(5, value: "5.0".sw))
        XCTAssert(Version.supportsMajorSwiftVersion(5, value: "5.1".sw))
        XCTAssert(Version.supportsMajorSwiftVersion(4, value: "5".sw))
        XCTAssertFalse(Version.supportsMajorSwiftVersion(5, value: "4".sw))
        XCTAssertFalse(Version.supportsMajorSwiftVersion(5, value: "4.0".sw))
    }

    func test_supportsMajorSwiftVersion_values() throws {
        XCTAssert(Version.supportsMajorSwiftVersion(5, values: ["5"].sw))
        XCTAssertFalse(Version.supportsMajorSwiftVersion(5, values: ["4"].sw))
        XCTAssert(Version.supportsMajorSwiftVersion(5, values: ["5.2", "4", "3.0", "3.1", "2"].sw))
        XCTAssertFalse(Version.supportsMajorSwiftVersion(5, values: ["4", "3.0", "3.1", "2"].sw))
        XCTAssert(Version.supportsMajorSwiftVersion(4, values: ["4", "3.0", "3.1", "2"].sw))
    }

}
