@testable import App

import XCTVapor


class HomeIndexModelTests: AppTestCase {

    func test_query() throws {
        // setup
        let pkgId = UUID()
        let pkg = Package(id: pkgId, url: "1".url)
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg,
                       name: "1",
                       owner: "foo").save(on: app.db).wait()
        try App.Version(package: pkg,
                        reference: .tag(.init(1, 2, 3)),
                        packageName: "Package",
                        commitDate: Date(timeIntervalSince1970: 0)).save(on: app.db).wait()
        try RecentPackage.refresh(on: app.db).wait()
        try RecentRelease.refresh(on: app.db).wait()

        // MUT
        let m = try HomeIndex.Model.query(database: app.db).wait()

        // validate
        let createdAt = try XCTUnwrap(pkg.createdAt)
        XCTAssertEqual(m.recentPackages, [
            .init(
                date: "\(date: createdAt, relativeTo: Current.date())",
                link: .init(label: "Package", url: "/packages/\(pkgId)")
            )
        ])
        XCTAssertEqual(m.recentReleases, [
            .init(
                date: "\(date: Date(timeIntervalSince1970: 0), relativeTo: Current.date())",
                link: .init(label: "Package", url: "/packages/\(pkgId)")
            )
        ])
    }

}
