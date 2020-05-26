@testable import App

import XCTVapor


class MaterializedViewsTests: AppTestCase {

    func test_recentPackages() throws {
        // setup
        let pkg = Package(id: UUID(), url: "1")
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg, defaultBranch: "default").create(on: app.db).wait()
        try Version(package: pkg,
                    reference: .tag(.init(1, 2, 3)),
                    packageName: "1",
                    commitDate: Date(timeIntervalSince1970: 0)).save(on: app.db).wait()
        // make sure to refresh the materialized view
        try RecentPackage.refresh(on: app.db).wait()

        // MUT
        let res = try RecentPackage.fetch(on: app.db).wait()

        // validate
        XCTAssertEqual(res.map(\.packageName), ["1"])
    }

}
