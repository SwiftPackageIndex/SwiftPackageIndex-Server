@testable import App

import XCTVapor


class SearchTests: AppTestCase {

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
        try Search.refresh(on: app.db).wait()

        // MUT
        let res = try Search.run(app.db, ["bar"]).wait()

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
        try Search.refresh(on: app.db).wait()

        // MUT
        let res = try Search.run(app.db, ["owner", "bar"]).wait()

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

    func test_quoting() throws {
        // Test searching for a `'`
        // setup
        let p1 = try savePackage(on: app.db, "1")
        let p2 = try savePackage(on: app.db, "2")
        try Repository(package: p1, summary: "some 'package'",
                       defaultBranch: "master",
                       name: "name 1",
                       owner: "owner 1").save(on: app.db).wait()
        try Repository(package: p2,
                       summary: "bar package",
                       defaultBranch: "master",
                       name: "name 2",
                       owner: "owner 2").save(on: app.db).wait()
        try Version(package: p1, reference: .branch("master"), packageName: "Foo").save(on: app.db).wait()
        try Version(package: p2, reference: .branch("master"), packageName: "Bar").save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()

        // MUT
        let res = try Search.run(app.db, ["'"]).wait()

        // validation
        XCTAssertEqual(res,
                       .init(hasMoreResults: false,
                             results: [
                                .init(packageId: try p1.requireID(),
                                      packageName: "Foo",
                                      repositoryName: "name 1",
                                      repositoryOwner: "owner 1",
                                      summary: "some 'package'")
                       ])
        )
    }


    func test_search_limit() throws {
        // setup
        let packages = (0..<25).map { Package(url: "\($0)".url) }
        try packages.save(on: app.db).wait()
        try packages.map { try Repository(package: $0, defaultBranch: "default",
                                          name: $0.url, owner: "foo") }
            .save(on: app.db)
            .wait()
        try packages.map { try Version(package: $0, reference: .branch("default"), packageName: "foo") }
            .save(on: app.db)
            .wait()
        try Search.refresh(on: app.db).wait()

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
        try packages.map { try Repository(package: $0, defaultBranch: "default",
                                          name: $0.url, owner: "foo") }
            .save(on: app.db)
            .wait()
        try packages.map { try Version(package: $0, reference: .branch("default"), packageName: "foo") }
            .save(on: app.db)
            .wait()
        try Search.refresh(on: app.db).wait()

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
            try Repository(package: p, summary: "\($0)", defaultBranch: "master",
                           name: "\($0)", owner: "foo").save(on: app.db).wait()
            try Version(package: p, reference: .branch("master"), packageName: "Foo").save(on: app.db).wait()
        }
        try Search.refresh(on: app.db).wait()

        // MUT
        let res = try Search.run(app.db, ["foo"]).wait()

        // validation
        XCTAssertEqual(res.results.count, 10)
        XCTAssertEqual(res.results.map(\.summary), ["9", "8", "7", "6", "5", "4", "3", "2", "1", "0"])
    }

    func test_exact_name_match() throws {
        // Ensure exact name matches are boosted
        // setup
        // We have three packages that all match in some way:
        // 1: exact package name match - we want this one to be at the top
        // 2: package name contains search term
        // 3: summary contains search term
        let p1 = Package(id: UUID(), url: "1", score: 10)
        let p2 = Package(id: UUID(), url: "2", score: 20)
        let p3 = Package(id: UUID(), url: "3", score: 30)
        try [p1, p2, p3].save(on: app.db).wait()
        try Repository(package: p1,
                       summary: "",
                       defaultBranch: "master",
                       name: "1",
                       owner: "foo").save(on: app.db).wait()
        try Repository(package: p2,
                       summary: "",
                       defaultBranch: "master",
                       name: "2",
                       owner: "foo").save(on: app.db).wait()
        try Repository(package: p3,
                       summary: "link",
                       defaultBranch: "master",
                       name: "3",
                       owner: "foo").save(on: app.db).wait()
        try Version(package: p1, reference: .branch("master"), packageName: "Ink")
            .save(on: app.db).wait()
        try Version(package: p2, reference: .branch("master"), packageName: "inkInName")
            .save(on: app.db).wait()
        try Version(package: p3, reference: .branch("master"), packageName: "some name")
            .save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()

        // MUT
        let res = try Search.run(app.db, ["ink"]).wait()

        XCTAssertEqual(res.results.map(\.repositoryName), ["1", "3", "2"])
    }

    func test_exact_name_match_whitespace() throws {
        // Ensure exact name matches are boosted, for package name with whitespace
        // setup
        // We have three packages that all match in some way:
        // 1: exact package name match - we want this one to be at the top
        // 2: package name contains search term
        // 3: summary contains search term
        let p1 = Package(id: UUID(), url: "1", score: 10)
        let p2 = Package(id: UUID(), url: "2", score: 20)
        let p3 = Package(id: UUID(), url: "3", score: 30)
        try [p1, p2, p3].save(on: app.db).wait()
        try Repository(package: p1,
                       summary: "",
                       defaultBranch: "master",
                       name: "1",
                       owner: "foo").save(on: app.db).wait()
        try Repository(package: p2,
                       summary: "",
                       defaultBranch: "master",
                       name: "2",
                       owner: "foo").save(on: app.db).wait()
        try Repository(package: p3,
                       summary: "foo bar",
                       defaultBranch: "master",
                       name: "3",
                       owner: "foo").save(on: app.db).wait()
        try Version(package: p1, reference: .branch("master"), packageName: "Foo bar")
            .save(on: app.db).wait()
        try Version(package: p2, reference: .branch("master"), packageName: "foobar")
            .save(on: app.db).wait()
        try Version(package: p3, reference: .branch("master"), packageName: "some name")
            .save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()

        // MUT
        let res = try Search.run(app.db, ["foo", "bar"]).wait()

        XCTAssertEqual(res.results.map(\.repositoryName), ["1", "3", "2"])
    }

    func test_exclude_null_fields() throws {
        // Ensure excluding results with NULL fields
        // setup
        // We have three packages that all match in some way:
        // 1: exact package name match - we want this one to be at the top
        // 2: package name contains search term
        // 3: summary contains search term
        let p1 = Package(id: UUID(), url: "1", score: 10)
        let p2 = Package(id: UUID(), url: "2", score: 20)
        let p3 = Package(id: UUID(), url: "3", score: 30)
        try [p1, p2, p3].save(on: app.db).wait()
        try Repository(package: p1,
                       summary: "",
                       defaultBranch: "master",
                       name: "1",
                       owner: "foo").save(on: app.db).wait()
        try Repository(package: p2,
                       summary: "",
                       defaultBranch: "master",
                       name: nil,
                       owner: "foo").save(on: app.db).wait()
        try Repository(package: p3,
                       summary: "foo bar",
                       defaultBranch: "master",
                       name: "3",
                       owner: nil).save(on: app.db).wait()
        try Version(package: p1, reference: .branch("master"), packageName: nil)
            .save(on: app.db).wait()
        try Version(package: p2, reference: .branch("master"), packageName: "foo2")
            .save(on: app.db).wait()
        try Version(package: p3, reference: .branch("master"), packageName: "foo3")
            .save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()

        // MUT
        let res = try Search.run(app.db, ["foo"]).wait()

        XCTAssertEqual(res.results, [])
    }

}
