@testable import App

import SQLKit
import XCTVapor


class SearchTests: AppTestCase {
    
    func test_DBRecord_packageURL() throws {
        XCTAssertEqual(Search.DBRecord(packageId: UUID(),
                                       repositoryName: "bar",
                                       repositoryOwner: "foo").packageURL,
                       "/foo/bar")
        XCTAssertEqual(Search.DBRecord(packageId: UUID(),
                                       repositoryName: "foo bar",
                                       repositoryOwner: "baz").packageURL,
                       "/baz/foo%20bar")
    }

    // TODO: remove once once https://github.com/vapor/sql-kit/pull/133 has been merged
    func test_union_two_arguments() throws {
        let db = app.db as! SQLDatabase
        let union = db.union(
            db.select()
                .column("id")
                .from("t1")
                .where("f1", .equal, "foo")
                .limit(2),
            db.select()
                .column("id")
                .from("t2")
                .where("f2", .equal, "bar")
                .limit(3)
        )
        XCTAssertEqual(renderSQL(union.query),
                       #"(SELECT "id" FROM "t1" WHERE "f1" = $1 LIMIT 2) UNION (SELECT "id" FROM "t2" WHERE "f2" = $2 LIMIT 3)"#)
    }

    // TODO: remove once once https://github.com/vapor/sql-kit/pull/133 has been merged
    func test_union_multiple_arguments() throws {
        let db = app.db as! SQLDatabase
        let union = db.union(
            db.select().column("id").from("t1"),
            db.select().column("id").from("t2"),
            db.select().column("id").from("t3")
        )
        XCTAssertEqual(renderSQL(union.query),
                       #"(SELECT "id" FROM "t1") UNION (SELECT "id" FROM "t2") UNION (SELECT "id" FROM "t3")"#)
    }

    func test_packageMatchQuery_single_term() throws {
        let q = Search.packageMatchQuery(on: app.db, terms: ["a"])
        XCTAssertEqual(renderSQL(q), #"SELECT 'package' AS "match_type", "id", "package_name", "name", "owner", "summary" FROM "search" WHERE CONCAT("package_name", ' ', COALESCE("summary", ''), ' ', "name", ' ', "owner") ~* $1 AND "package_name" IS NOT NULL AND "owner" IS NOT NULL AND "name" IS NOT NULL ORDER BY LOWER("package_name") = $2 DESC, "score" DESC, "package_name" ASC"#)
        XCTAssertEqual(binds(q), ["a", "a"])
    }

    func test_packageMatchQuery_multiple_terms() throws {
        let q = Search.packageMatchQuery(on: app.db, terms: ["a", "b"])
        XCTAssertEqual(renderSQL(q), #"SELECT 'package' AS "match_type", "id", "package_name", "name", "owner", "summary" FROM "search" WHERE CONCAT("package_name", ' ', COALESCE("summary", ''), ' ', "name", ' ', "owner") ~* $1 AND CONCAT("package_name", ' ', COALESCE("summary", ''), ' ', "name", ' ', "owner") ~* $2 AND "package_name" IS NOT NULL AND "owner" IS NOT NULL AND "name" IS NOT NULL ORDER BY LOWER("package_name") = $3 DESC, "score" DESC, "package_name" ASC"#)
        XCTAssertEqual(binds(q), ["a", "b", "a b"])
    }

    func test_keywordMatchQuery_single_term() throws {
        let q = Search.keywordMatchQuery(on: app.db, terms: ["a"])
        XCTAssertEqual(renderSQL(q), #"SELECT 'keyword' AS "match_type", NULL, NULL, NULL, NULL, NULL, NULL FROM "search" WHERE $1 LIKE ANY("keywords")"#)
        XCTAssertEqual(binds(q), ["a"])
    }

    func test_keywordMatchQuery_multiple_terms() throws {
        let q = Search.keywordMatchQuery(on: app.db, terms: ["a", "b"])
        XCTAssertEqual(renderSQL(q), #"SELECT 'keyword' AS "match_type", NULL, NULL, NULL, NULL, NULL, NULL FROM "search" WHERE $1 LIKE ANY("keywords")"#)
        XCTAssertEqual(binds(q), ["a b"])
    }

    func test_query_sql() throws {
        // Test to confirm shape of rendered search SQL
        do {  // single search term
            // MUT
            let query = Search.query(app.db, ["a"], page: 1, pageSize: 20)
            // validate
            let inner = Search.packageMatchQuery(on: app.db,
                                                 terms: ["a"],
                                                 offset: 0,
                                                 limit: 21)
            XCTAssertEqual(renderSQL(query?.select),
                           #"SELECT * FROM (\#(renderSQL(inner))) AS "t""#)
        }
        do {  // multiple search terms
            // MUT
            let query = Search.query(app.db, ["a", "b"], page: 1, pageSize: 20)
            // validate
            let inner = Search.packageMatchQuery(on: app.db,
                                                 terms: ["a", "b"],
                                                 offset: 0,
                                                 limit: 21)
            XCTAssertEqual(renderSQL(query?.select),
                           #"SELECT * FROM (\#(renderSQL(inner))) AS "t""#)
        }
    }

    func test_fetch_single() throws {
        // Test search with a single term
        // setup
        let p1 = try savePackage(on: app.db, "1")
        let p2 = try savePackage(on: app.db, "2")
        try Repository(package: p1,
                       defaultBranch: "main",
                       summary: "some package").save(on: app.db).wait()
        try Repository(package: p2,
                       defaultBranch: "main",
                       name: "name 2",
                       owner: "owner 2",
                       summary: "bar package").save(on: app.db).wait()
        try Version(package: p1, packageName: "Foo", reference: .branch("main")).save(on: app.db).wait()
        try Version(package: p2, packageName: "Bar", reference: .branch("main")).save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()
        
        // MUT
        let res = try Search.fetch(app.db, ["bar"], page: 1, pageSize: 20).wait()
        
        // validation
        XCTAssertEqual(res,
                       .init(hasMoreResults: false,
                             results: [
                                .init(packageId: try p2.requireID(),
                                      packageName: "Bar",
                                      packageURL: "/owner%202/name%202",
                                      repositoryName: "name 2",
                                      repositoryOwner: "owner 2",
                                      summary: "bar package")
                             ])
        )
    }
    
    func test_fetch_multiple() throws {
        // Test search with multiple terms ("and")
        // setup
        let p1 = try savePackage(on: app.db, "1")
        let p2 = try savePackage(on: app.db, "2")
        try Repository(package: p1,
                       defaultBranch: "main",
                       name: "package 1",
                       owner: "owner",
                       summary: "package 1 description").save(on: app.db).wait()
        try Repository(package: p2,
                       defaultBranch: "main",
                       name: "package 2",
                       owner: "owner",
                       summary: "package 2 description").save(on: app.db).wait()
        try Version(package: p1, packageName: "Foo", reference: .branch("main")).save(on: app.db).wait()
        try Version(package: p2, packageName: "Bar", reference: .branch("main")).save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()
        
        // MUT
        let res = try Search.fetch(app.db, ["owner", "bar"], page: 1, pageSize: 20).wait()
        
        // validation
        XCTAssertEqual(res,
                       .init(hasMoreResults: false,
                             results: [
                                .init(packageId: try p2.requireID(),
                                      packageName: "Bar",
                                      packageURL: "/owner/package%202",
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
        try Repository(package: p1,
                       defaultBranch: "main",
                       name: "name 1",
                       owner: "owner 1",
                       summary: "some 'package'").save(on: app.db).wait()
        try Repository(package: p2,
                       defaultBranch: "main",
                       name: "name 2",
                       owner: "owner 2",
                       summary: "bar package").save(on: app.db).wait()
        try Version(package: p1, packageName: "Foo", reference: .branch("main")).save(on: app.db).wait()
        try Version(package: p2, packageName: "Bar", reference: .branch("main")).save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()
        
        // MUT
        let res = try Search.fetch(app.db, ["'"], page: 1, pageSize: 20).wait()
        
        // validation
        XCTAssertEqual(res,
                       .init(hasMoreResults: false,
                             results: [
                                .init(packageId: try p1.requireID(),
                                      packageName: "Foo",
                                      packageURL: "/owner%201/name%201",
                                      repositoryName: "name 1",
                                      repositoryOwner: "owner 1",
                                      summary: "some 'package'")
                             ])
        )
    }
    
    
    func test_search_pagination() throws {
        // setup
        let packages = (0..<9).map { idx in
            Package(url: "\(idx)".url, score: 15 - idx)
        }
        try packages.save(on: app.db).wait()
        try packages.map { try Repository(package: $0, defaultBranch: "default",
                                          name: $0.url, owner: "foo") }
            .save(on: app.db)
            .wait()
        try packages.map { try Version(package: $0, packageName: "foo", reference: .branch("default")) }
            .save(on: app.db)
            .wait()
        try Search.refresh(on: app.db).wait()
        
        do {  // first page
            // MUT
            let res = try API.search(database: app.db,
                                     query: "foo",
                                     page: 1,
                                     pageSize: 3).wait()

            // validate
            XCTAssertTrue(res.hasMoreResults)
            XCTAssertEqual(res.results.map(\.repositoryName),
                           ["0", "1", "2"])
        }

        do {  // second page
            // MUT
            let res = try API.search(database: app.db,
                                     query: "foo",
                                     page: 2,
                                     pageSize: 3).wait()

            // validate
            XCTAssertTrue(res.hasMoreResults)
            XCTAssertEqual(res.results.map(\.repositoryName),
                           ["3", "4", "5"])
        }

        do {  // third page
            // MUT
            let res = try API.search(database: app.db,
                                     query: "foo",
                                     page: 3,
                                     pageSize: 3).wait()

            // validate
            XCTAssertFalse(res.hasMoreResults)
            XCTAssertEqual(res.results.map(\.repositoryName),
                           ["6", "7", "8"])
        }
    }

    func test_search_pagination_invalid_input() throws {
        // Test invalid pagination inputs
        // setup
        let packages = (0..<9).map { idx in
            Package(url: "\(idx)".url, score: 15 - idx)
        }
        try packages.save(on: app.db).wait()
        try packages.map { try Repository(package: $0, defaultBranch: "default",
                                          name: $0.url, owner: "foo") }
            .save(on: app.db)
            .wait()
        try packages.map { try Version(package: $0, packageName: "foo", reference: .branch("default")) }
            .save(on: app.db)
            .wait()
        try Search.refresh(on: app.db).wait()

        do {  // page out of bounds (too large)
            // MUT
            let res = try API.search(database: app.db,
                                     query: "foo",
                                     page: 4,
                                     pageSize: 3).wait()

            // validate
            XCTAssertFalse(res.hasMoreResults)
            XCTAssertEqual(res.results.map(\.repositoryName),
                           [])
        }

        do {  // page out of bounds (too small - will be clamped to page 1)
            // MUT
            let res = try API.search(database: app.db,
                                     query: "foo",
                                     page: 0,
                                     pageSize: 3).wait()
            XCTAssertTrue(res.hasMoreResults)
            XCTAssertEqual(res.results.map(\.repositoryName),
                           ["0", "1", "2"])
        }
    }

    func test_order_by_score() throws {
        // setup
        try (0..<10).shuffled().forEach {
            let p = Package(id: UUID(), url: "\($0)".url, score: $0)
            try p.save(on: app.db).wait()
            try Repository(package: p,
                           defaultBranch: "main",
                           name: "\($0)",
                           owner: "foo",
                           summary: "\($0)").save(on: app.db).wait()
            try Version(package: p, packageName: "Foo", reference: .branch("main")).save(on: app.db).wait()
        }
        try Search.refresh(on: app.db).wait()
        
        // MUT
        let res = try Search.fetch(app.db, ["foo"], page: 1, pageSize: 20).wait()
        
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
                       defaultBranch: "main",
                       name: "1",
                       owner: "foo",
                       summary: "").save(on: app.db).wait()
        try Repository(package: p2,
                       defaultBranch: "main",
                       name: "2",
                       owner: "foo",
                       summary: "").save(on: app.db).wait()
        try Repository(package: p3,
                       defaultBranch: "main",
                       name: "3",
                       owner: "foo",
                       summary: "link").save(on: app.db).wait()
        try Version(package: p1, packageName: "Ink", reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: p2, packageName: "inkInName", reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: p3, packageName: "some name", reference: .branch("main"))
            .save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()
        
        // MUT
        let res = try Search.fetch(app.db, ["ink"], page: 1, pageSize: 20).wait()
        
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
                       defaultBranch: "main",
                       name: "1",
                       owner: "foo",
                       summary: "").save(on: app.db).wait()
        try Repository(package: p2,
                       defaultBranch: "main",
                       name: "2",
                       owner: "foo",
                       summary: "").save(on: app.db).wait()
        try Repository(package: p3,
                       defaultBranch: "main",
                       name: "3",
                       owner: "foo",
                       summary: "foo bar").save(on: app.db).wait()
        try Version(package: p1, packageName: "Foo bar", reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: p2, packageName: "foobar", reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: p3, packageName: "some name", reference: .branch("main"))
            .save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()
        
        // MUT
        let res = try Search.fetch(app.db, ["foo", "bar"], page: 1, pageSize: 20).wait()
        
        XCTAssertEqual(res.results.map(\.repositoryName), ["1", "3", "2"])
    }
    
    func test_exclude_null_fields() throws {
        // Ensure excluding results with NULL fields
        // setup
        // Three packages that all match but each has a different required field with
        // a NULL value
        let p1 = Package(id: UUID(), url: "1", score: 10)
        let p2 = Package(id: UUID(), url: "2", score: 20)
        let p3 = Package(id: UUID(), url: "3", score: 30)
        try [p1, p2, p3].save(on: app.db).wait()
        try Repository(package: p1,
                       defaultBranch: "main",
                       name: "1",
                       owner: "foo",
                       summary: "").save(on: app.db).wait()
        try Repository(package: p2,
                       defaultBranch: "main",
                       name: nil,
                       owner: "foo",
                       summary: "").save(on: app.db).wait()
        try Repository(package: p3,
                       defaultBranch: "main",
                       name: "3",
                       owner: nil,
                       summary: "foo bar").save(on: app.db).wait()
        try Version(package: p1, packageName: nil, reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: p2, packageName: "foo2", reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: p3, packageName: "foo3", reference: .branch("main"))
            .save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()
        
        // MUT
        let res = try Search.fetch(app.db, ["foo"], page: 1, pageSize: 20).wait()
        
        XCTAssertEqual(res.results, [])
    }

    func test_sanitize() throws {
        XCTAssertEqual(Search.sanitize(["*"]), ["\\*"])
        XCTAssertEqual(Search.sanitize(["?"]), ["\\?"])
        XCTAssertEqual(Search.sanitize(["("]), ["\\("])
        XCTAssertEqual(Search.sanitize([")"]), ["\\)"])
        XCTAssertEqual(Search.sanitize(["["]), ["\\["])
        XCTAssertEqual(Search.sanitize(["]"]), ["\\]"])
    }

    func test_invalid_characters() throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/974
        // Ensure we don't raise a 500 for certain characters
        // "server: invalid regular expression: quantifier operand invalid"

        // MUT
        let res = try Search.fetch(app.db, ["*"], page: 1, pageSize: 20).wait()

        // validation
        XCTAssertEqual(res, .init(hasMoreResults: false, results: []))
    }

    func test_search_topic() throws {
        throw XCTSkip("WIP")
        // Test searching for a topic
        // setup
        // p1: decoy
        // p2: match
        let p1 = Package(id: UUID(), url: "1", score: 10)
        let p2 = Package(id: UUID(), url: "2", score: 20)
        try [p1, p2].save(on: app.db).wait()
        try Repository(package: p1,
                       defaultBranch: "main",
                       name: "1",
                       owner: "foo",
                       summary: "").save(on: app.db).wait()
        try Repository(package: p2,
                       defaultBranch: "main",
                       keywords: ["keyword"],
                       name: "2",
                       owner: "foo",
                       summary: "").save(on: app.db).wait()
        try Version(package: p1, packageName: "p1", reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: p2, packageName: "p2", reference: .branch("main"))
            .save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()

        // MUT
        let res = try Search.fetch(app.db, ["keyword"], page: 1, pageSize: 20).wait()

        XCTAssertEqual(res.results.map(\.repositoryName), ["2"])
    }

}
