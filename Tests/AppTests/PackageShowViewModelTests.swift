@testable import App

import XCTVapor


class PackageShowViewModelTests: AppTestCase {

    func test_query_basic() throws {
        let pkg = try savePackage(on: app.db, "1".url)
        try Repository(id: UUID(),
                   package: pkg,
                   summary: "summary",
                   defaultBranch: "master",
                   license: .mit,
                   stars: 17,
                   forks: 42).save(on: app.db).wait()
        let pkgId = try XCTUnwrap(pkg.id)

        // MUT
        let m = try PackageShowView.Model.query(database: app.db, packageId: pkgId).wait()

        // validate
        XCTAssertEqual(m.title, "–")
        XCTAssertEqual(m.url, "1")
        XCTAssertEqual(m.license, .mit)
        XCTAssertEqual(m.summary, "summary")
        XCTAssertEqual(m.authors, [])
        XCTAssertEqual(m.history, nil)
        XCTAssertEqual(m.activity, nil)
        XCTAssertEqual(m.products, nil)
    }

}
