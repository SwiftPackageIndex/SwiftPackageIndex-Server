@testable import App

import XCTVapor


class PackageShowModelTests: AppTestCase {

    func test_query_basic() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1".url)
        try Repository(package: pkg,
                       summary: "summary",
                       defaultBranch: "master",
                       license: .mit,
                       stars: 17,
                       forks: 42).save(on: app.db).wait()
        let version = try App.Version(package: pkg,
                                      reference: .branch("master"),
                                      packageName: "test package")
        try version.save(on: app.db).wait()
        try Product(version: version,
                    type: .library, name: "lib 1").save(on: app.db).wait()
        let pkgId = try XCTUnwrap(pkg.id)

        // MUT
        let m = try PackageShow.Model.query(database: app.db, packageId: pkgId).wait()

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
        XCTAssertThrowsError(try PackageShow.Model.query(database: app.db, packageId: pkgId).wait()) {
            let error = try? XCTUnwrap($0 as? Vapor.Abort)
            XCTAssertEqual(error?.identifier, "404")
        }
    }

    func test_lpInfoGroups_by_swiftVersions() throws {
        // Test grouping by swift versions
        let lnk = Link(name: "1", url: "1")
        let v1 = Version(link: lnk, swiftVersions: ["1"], platforms: [.macos("10")])
        let v2 = Version(link: lnk, swiftVersions: ["2"], platforms: [.macos("10")])
        let v3 = Version(link: lnk, swiftVersions: ["3"], platforms: [.macos("10")])

        XCTAssertEqual(lpInfoGroups(.init(stable: v1, beta: v2, latest: v3)),
                       [[\.stable], [\.beta], [\.latest]])
        XCTAssertEqual(lpInfoGroups(.init(stable: v1, beta: v2, latest: v2)),
                       [[\.stable], [\.beta, \.latest]])
        XCTAssertEqual(lpInfoGroups(.init(stable: v1, beta: v1, latest: v2)),
                       [[\.stable, \.beta], [\.latest]])
        XCTAssertEqual(lpInfoGroups(.init(stable: v2, beta: v1, latest: v2)),
                       [[\.stable, \.latest], [\.beta]])
        XCTAssertEqual(lpInfoGroups(.init(stable: v1, beta: v1, latest: v1)),
                       [[\.stable, \.beta, \.latest]])
    }

    func test_lpInfoGroups_by_platforms() throws {
        // Test grouping by platforms
        let lnk = Link(name: "1", url: "1")
        let v1 = Version(link: lnk, swiftVersions: ["1"], platforms: [.macos("10")])
        let v2 = Version(link: lnk, swiftVersions: ["1"], platforms: [.macos("11")])
        let v3 = Version(link: lnk, swiftVersions: ["1"], platforms: [.macos("12")])

        XCTAssertEqual(lpInfoGroups(.init(stable: v1, beta: v2, latest: v3)),
                       [[\.stable], [\.beta], [\.latest]])
        XCTAssertEqual(lpInfoGroups(.init(stable: v1, beta: v2, latest: v2)),
                       [[\.stable], [\.beta, \.latest]])
        XCTAssertEqual(lpInfoGroups(.init(stable: v1, beta: v1, latest: v2)),
                       [[\.stable, \.beta], [\.latest]])
        XCTAssertEqual(lpInfoGroups(.init(stable: v2, beta: v1, latest: v2)),
                       [[\.stable, \.latest], [\.beta]])
        XCTAssertEqual(lpInfoGroups(.init(stable: v1, beta: v1, latest: v1)),
                       [[\.stable, \.beta, \.latest]])
    }

    func test_lpInfoGroups_ignores_link() throws {
        // Test to ensure the link isn't part of the grouping
        let l1 = Link(name: "1", url: "1")
        let l2 = Link(name: "2", url: "2")
        let l3 = Link(name: "3", url: "3")
        let v1 = Version(link: l1, swiftVersions: ["1"], platforms: [.macos("10")])
        let v2 = Version(link: l2, swiftVersions: ["1"], platforms: [.macos("10")])
        let v3 = Version(link: l3, swiftVersions: ["1"], platforms: [.macos("10")])

        XCTAssertEqual(lpInfoGroups(.init(stable: v1, beta: v2, latest: v3)),
                       [[\.stable, \.beta, \.latest]])
    }
}


// local typealiases / references to make tests more readable
fileprivate typealias Link = PackageShow.Model.Link
fileprivate typealias Version = PackageShow.Model.Version
let lpInfoGroups = PackageShow.Model.lpInfoGroups
