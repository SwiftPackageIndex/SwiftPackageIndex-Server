@testable import App

import XCTVapor


class BuildIndexModelTests: AppTestCase {

    func test_init_no_name() throws {
        // Tests behaviour when we're lacking data
        // setup package without package name
        let pkg = try savePackage(on: app.db, "1".url)
        try Repository(package: pkg,
                       summary: "summary",
                       defaultBranch: "main",
                       license: .mit,
                       name: "bar",
                       owner: "foo",
                       stars: 17,
                       forks: 42).save(on: app.db).wait()

        // MUT
        let m = BuildIndex.Model(package: pkg)

        // validate
        XCTAssertNil(m)
    }

    func test_buildCount() throws {
        let m = BuildIndex.Model.mock

        // MUT
        let count = m.buildCount

        // validate
        XCTAssertEqual(count, 72)
    }

}
