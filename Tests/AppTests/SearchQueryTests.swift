@testable import App

import XCTVapor


class SearchQueryTests: AppTestCase {

    func test_regexClause() throws {
        XCTAssertEqual(
            API.SearchQuery.regexClause("foo"),
            "coalesce(v.package_name) || ' ' || coalesce(r.summary, '') || ' ' || coalesce(r.name, '') || ' ' || coalesce(r.owner, '') ~* 'foo'"
        )
    }

    func test_build() throws {
        XCTAssertEqual(
            API.SearchQuery.build(["foo"]),
            API.SearchQuery.preamble + "\nand " + API.SearchQuery.regexClause("foo")
        )
    }

    func test_run_single() throws {
        // Test search with a single term
        // setup
        let p1 = try savePackage(on: app.db, "1")
        let p2 = try savePackage(on: app.db, "2")
        try Repository(package: p1, summary: "some package", defaultBranch: "master").save(on: app.db).wait()
        try Repository(package: p2,
                       summary: "bar package",
                       defaultBranch: "master",
                       name: "name 2",
                       owner: "owner 2").save(on: app.db).wait()
        try Version(package: p1, reference: .branch("master"), packageName: "Foo").save(on: app.db).wait()
        try Version(package: p2, reference: .branch("master"), packageName: "Bar").save(on: app.db).wait()

        // MUT
        let res = try API.SearchQuery.run(app.db, ["bar"]).wait()

        // validation
        XCTAssertEqual(res, [
            .init(packageId: try p2.requireID(),
                  packageName: "Bar",
                  repositoryName: "name 2",
                  repositoryOwner: "owner 2",
                  summary: "bar package")
        ])
    }

    func test_run_multiple() throws {
        // Test search with multiple terms ("and")
        // setup
        let p1 = try savePackage(on: app.db, "1")
        let p2 = try savePackage(on: app.db, "2")
        try Repository(package: p1,
                       summary: "package 1 description",
                       defaultBranch: "master",
                       name: "package 1",
                       owner: "owner").save(on: app.db).wait()
        try Repository(package: p2,
                       summary: "package 2 description",
                       defaultBranch: "master",
                       name: "package 2",
                       owner: "owner").save(on: app.db).wait()
        try Version(package: p1, reference: .branch("master"), packageName: "Foo").save(on: app.db).wait()
        try Version(package: p2, reference: .branch("master"), packageName: "Bar").save(on: app.db).wait()

        // MUT
        let res = try API.SearchQuery.run(app.db, ["owner", "bar"]).wait()

        // validation
        XCTAssertEqual(res, [
            .init(packageId: try p2.requireID(),
                  packageName: "Bar",
                  repositoryName: "package 2",
                  repositoryOwner: "owner",
                  summary: "package 2 description")
        ])
    }


}
