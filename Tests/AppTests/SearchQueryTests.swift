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
            API.SearchQuery.preamble + "\n  and "
                + API.SearchQuery.regexClause("foo")
                + "\n  order by p.score desc"
                + "\n  limit 25"
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
        XCTAssertEqual(res,
                       .init(hasMoreResults: false,
                             results: [
                                .init(packageId: try p2.requireID(),
                                      packageName: "Bar",
                                      repositoryName: "name 2",
                                      repositoryOwner: "owner 2",
                                      summary: "bar package")
                       ])
        )
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
        XCTAssertEqual(res,
                       .init(hasMoreResults: false,
                             results: [
                                .init(packageId: try p2.requireID(),
                                      packageName: "Bar",
                                      repositoryName: "package 2",
                                      repositoryOwner: "owner",
                                      summary: "package 2 description")
                       ])
        )
    }


    func test_search_limit() throws {
        // setup
        let packages = (0..<25).map { Package(url: "\($0)".url) }
        try packages.save(on: app.db).wait()
        try packages.map { try Repository(package: $0, defaultBranch: "default") }
            .save(on: app.db)
            .wait()
        try packages.map { try Version(package: $0, reference: .branch("default"), packageName: "foo") }
            .save(on: app.db)
            .wait()

        // MUT
        let res = try API.search(database: app.db, query: "foo").wait()

        // validate
        XCTAssertTrue(res.hasMoreResults)
        XCTAssertEqual(res.results.count, 20)
    }

    func test_search_limit_leeway() throws {
        // Tests leeway: we only start cutting off if we have 25 or more results
        // setup
        let packages = (0..<21).map { Package(url: "\($0)".url) }
        try packages.save(on: app.db).wait()
        try packages.map { try Repository(package: $0, defaultBranch: "default") }
            .save(on: app.db)
            .wait()
        try packages.map { try Version(package: $0, reference: .branch("default"), packageName: "foo") }
            .save(on: app.db)
            .wait()

        // MUT
        let res = try API.search(database: app.db, query: "foo").wait()

        // validate
        XCTAssertFalse(res.hasMoreResults)
        XCTAssertEqual(res.results.count, 21)
    }

    func test_order_by_score() throws {
        // setup
        try (0..<10).shuffled().forEach {
            let p = Package(id: UUID(), url: "\($0)".url, score: $0)
            try p.save(on: app.db).wait()
            try Repository(package: p, summary: "\($0)", defaultBranch: "master").save(on: app.db).wait()
            try Version(package: p, reference: .branch("master"), packageName: "Foo").save(on: app.db).wait()
        }

        // MUT
        let res = try API.SearchQuery.run(app.db, ["foo"]).wait()

        // validation
        XCTAssertEqual(res.results.count, 10)
        XCTAssertEqual(res.results.map(\.summary), ["9", "8", "7", "6", "5", "4", "3", "2", "1", "0"])
    }

}
