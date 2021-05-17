@testable import App

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
    
    func test_query_single() throws {
        // Test search with a single term
        // setup
        let p1 = try savePackage(on: app.db, "1")
        let p2 = try savePackage(on: app.db, "2")
        try Repository(package: p1, summary: "some package", defaultBranch: "main").save(on: app.db).wait()
        try Repository(package: p2,
                       summary: "bar package",
                       defaultBranch: "main",
                       name: "name 2",
                       owner: "owner 2").save(on: app.db).wait()
        try Version(package: p1, packageName: "Foo", reference: .branch("main")).save(on: app.db).wait()
        try Version(package: p2, packageName: "Bar", reference: .branch("main")).save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()
        
        // MUT
        let res = try Search.query(app.db, ["bar"], page: 1, pageSize: 20).wait()
        
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
    
    func test_query_multiple() throws {
        // Test search with multiple terms ("and")
        // setup
        let p1 = try savePackage(on: app.db, "1")
        let p2 = try savePackage(on: app.db, "2")
        try Repository(package: p1,
                       summary: "package 1 description",
                       defaultBranch: "main",
                       name: "package 1",
                       owner: "owner").save(on: app.db).wait()
        try Repository(package: p2,
                       summary: "package 2 description",
                       defaultBranch: "main",
                       name: "package 2",
                       owner: "owner").save(on: app.db).wait()
        try Version(package: p1, packageName: "Foo", reference: .branch("main")).save(on: app.db).wait()
        try Version(package: p2, packageName: "Bar", reference: .branch("main")).save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()
        
        // MUT
        let res = try Search.query(app.db, ["owner", "bar"], page: 1, pageSize: 20).wait()
        
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
        try Repository(package: p1, summary: "some 'package'",
                       defaultBranch: "main",
                       name: "name 1",
                       owner: "owner 1").save(on: app.db).wait()
        try Repository(package: p2,
                       summary: "bar package",
                       defaultBranch: "main",
                       name: "name 2",
                       owner: "owner 2").save(on: app.db).wait()
        try Version(package: p1, packageName: "Foo", reference: .branch("main")).save(on: app.db).wait()
        try Version(package: p2, packageName: "Bar", reference: .branch("main")).save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()
        
        // MUT
        let res = try Search.query(app.db, ["'"], page: 1, pageSize: 20).wait()
        
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

        do {  // page out of bounds (too small)
            // MUT
            XCTAssertThrowsError(
                try API.search(database: app.db,
                               query: "foo",
                               page: 0,
                               pageSize: 3).wait()
            ) { error in
                XCTAssertEqual(error.localizedDescription,
                               "Error: page is one-based and must be greater than zero")
            }
        }
    }

    func test_order_by_score() throws {
        // setup
        try (0..<10).shuffled().forEach {
            let p = Package(id: UUID(), url: "\($0)".url, score: $0)
            try p.save(on: app.db).wait()
            try Repository(package: p, summary: "\($0)", defaultBranch: "main",
                           name: "\($0)", owner: "foo").save(on: app.db).wait()
            try Version(package: p, packageName: "Foo", reference: .branch("main")).save(on: app.db).wait()
        }
        try Search.refresh(on: app.db).wait()
        
        // MUT
        let res = try Search.query(app.db, ["foo"], page: 1, pageSize: 20).wait()
        
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
                       defaultBranch: "main",
                       name: "1",
                       owner: "foo").save(on: app.db).wait()
        try Repository(package: p2,
                       summary: "",
                       defaultBranch: "main",
                       name: "2",
                       owner: "foo").save(on: app.db).wait()
        try Repository(package: p3,
                       summary: "link",
                       defaultBranch: "main",
                       name: "3",
                       owner: "foo").save(on: app.db).wait()
        try Version(package: p1, packageName: "Ink", reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: p2, packageName: "inkInName", reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: p3, packageName: "some name", reference: .branch("main"))
            .save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()
        
        // MUT
        let res = try Search.query(app.db, ["ink"], page: 1, pageSize: 20).wait()
        
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
                       defaultBranch: "main",
                       name: "1",
                       owner: "foo").save(on: app.db).wait()
        try Repository(package: p2,
                       summary: "",
                       defaultBranch: "main",
                       name: "2",
                       owner: "foo").save(on: app.db).wait()
        try Repository(package: p3,
                       summary: "foo bar",
                       defaultBranch: "main",
                       name: "3",
                       owner: "foo").save(on: app.db).wait()
        try Version(package: p1, packageName: "Foo bar", reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: p2, packageName: "foobar", reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: p3, packageName: "some name", reference: .branch("main"))
            .save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()
        
        // MUT
        let res = try Search.query(app.db, ["foo", "bar"], page: 1, pageSize: 20).wait()
        
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
                       summary: "",
                       defaultBranch: "main",
                       name: "1",
                       owner: "foo").save(on: app.db).wait()
        try Repository(package: p2,
                       summary: "",
                       defaultBranch: "main",
                       name: nil,
                       owner: "foo").save(on: app.db).wait()
        try Repository(package: p3,
                       summary: "foo bar",
                       defaultBranch: "main",
                       name: "3",
                       owner: nil).save(on: app.db).wait()
        try Version(package: p1, packageName: nil, reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: p2, packageName: "foo2", reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: p3, packageName: "foo3", reference: .branch("main"))
            .save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()
        
        // MUT
        let res = try Search.query(app.db, ["foo"], page: 1, pageSize: 20).wait()
        
        XCTAssertEqual(res.results, [])
    }

    func test_sanitize() throws {
        XCTAssertEqual(Search.sanitize(["a*b"]), ["ab"])
        XCTAssertEqual(Search.sanitize(["a?b"]), ["ab"])
        XCTAssertEqual(Search.sanitize(["a(b"]), ["ab"])
        XCTAssertEqual(Search.sanitize(["a)b"]), ["ab"])
        XCTAssertEqual(Search.sanitize(["a[b"]), ["ab"])
        XCTAssertEqual(Search.sanitize(["a]b"]), ["ab"])
        XCTAssertEqual(Search.sanitize(["*"]), [])
    }

    func test_invalid_characters() throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/974
        // Ensure we don't raise a 500 for certain characters
        // "server: invalid regular expression: quantifier operand invalid"

        // MUT
        let res = try Search.query(app.db, ["*"], page: 1, pageSize: 20).wait()

        // validation
        XCTAssertEqual(res, .init(hasMoreResults: false, results: []))
    }

}
