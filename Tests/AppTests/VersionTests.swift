@testable import App

import XCTVapor


class VersionTests: AppTestCase {
    
    func test_Version_save() throws {
        let pkg = try savePackage(on: app.db, "1".url)
        let v = try Version(package: pkg)
        try v.save(on: app.db).wait()
        XCTAssertEqual(v.$package.id, pkg.id)
        v.commit = "commit"
        v.branchName = "branch"
        v.packageName = "pname"
        v.tagName = "tag"
        v.supportedPlatforms = ["ios_13", "macos_10.15"]
        v.swiftVersions = ["4.0", "5.2"]
        try v.save(on: app.db).wait()
        do {
            let v = try XCTUnwrap(Version.find(v.id, on: app.db).wait())
            XCTAssertEqual(v.commit, "commit")
            XCTAssertEqual(v.branchName, "branch")
            XCTAssertEqual(v.packageName, "pname")
            XCTAssertEqual(v.tagName, "tag")
            XCTAssertEqual(v.supportedPlatforms, ["ios_13", "macos_10.15"])
            XCTAssertEqual(v.swiftVersions, ["4.0", "5.2"])
        }
    }

    func test_Version_empty_array_error() throws {
        // Test for
        // invalid field: swift_versions type: Array<SemVer> error: Unexpected data type: JSONB[]. Expected array.
        // Fix is .sql(.default("{}"))
        let pkg = try savePackage(on: app.db, "1".url)
        let v = try Version(package: pkg)
        try v.save(on: app.db).wait()
        _ = try XCTUnwrap(Version.find(v.id, on: app.db).wait())
    }

    func test_delete_cascade() throws {
        // delete package must delete version
        let pkg = Package(id: UUID(), url: "1".url, status: .none)
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
}
