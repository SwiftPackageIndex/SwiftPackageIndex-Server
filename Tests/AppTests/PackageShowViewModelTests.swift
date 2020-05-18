@testable import App

import XCTVapor


class PackageShowViewModelTests: AppTestCase {

    func test_query_basic() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1".url)
        try Repository(package: pkg,
                       summary: "summary",
                       defaultBranch: "master",
                       license: .mit,
                       stars: 17,
                       forks: 42).save(on: app.db).wait()
        let version = try Version(package: pkg,
                                  reference: .branch("master"),
                                  packageName: "test package")
        try version.save(on: app.db).wait()
        try Product(version: version,
                    type: .library, name: "lib 1").save(on: app.db).wait()
        let pkgId = try XCTUnwrap(pkg.id)

        // MUT
        let m = try PackageShowView.Model.query(database: app.db, packageId: pkgId).wait()

        // validate
        XCTAssertEqual(m.title, "test package")
        XCTAssertEqual(m.url, "1")
        XCTAssertEqual(m.license, .mit)
        XCTAssertEqual(m.summary, "summary")
        XCTAssertEqual(m.authors, [])
        XCTAssertEqual(m.history, nil)
        XCTAssertEqual(m.activity, nil)
        XCTAssertEqual(m.products, .init(libraries: 1, executables: 0))
    }

    func test_query_no_title() throws {
        // Tests behaviour when we're lacking data
        // setup package without package name
        let pkg = try savePackage(on: app.db, "1".url)
        let pkgId = try XCTUnwrap(pkg.id)

        // MUT
        XCTAssertThrowsError(try PackageShowView.Model.query(database: app.db, packageId: pkgId).wait()) {
            let error = try? XCTUnwrap($0 as? Vapor.Abort)
            XCTAssertEqual(error?.identifier, "404")
        }
    }
}
