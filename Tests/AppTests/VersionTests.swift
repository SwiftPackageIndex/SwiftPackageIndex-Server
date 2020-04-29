@testable import App

import XCTVapor


class VersionTests: XCTestCase {
    var app: Application!

    override func setUpWithError() throws {
        app = try setup(.testing)
    }

    override func tearDownWithError() throws {
        app.shutdown()
    }

    func test_Version_save() throws {
        let pkg = try savePackage(on: app.db, "1".url)
        let v = try Version(package: pkg)
        try v.save(on: app.db).wait()
        XCTAssertEqual(v.$package.id, pkg.id)
        v.commit = "commit"
        v.branchName = "branch"
        v.packageName = "pname"
        v.tagName = "tag"
        try v.save(on: app.db).wait()
        do {
            let v = try XCTUnwrap(Version.find(v.id, on: app.db).wait())
            XCTAssertEqual(v.commit, "commit")
            XCTAssertEqual(v.branchName, "branch")
            XCTAssertEqual(v.packageName, "pname")
            XCTAssertEqual(v.tagName, "tag")
        }
    }
}
