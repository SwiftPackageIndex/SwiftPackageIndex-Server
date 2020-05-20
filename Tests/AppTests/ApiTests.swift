@testable import App

import SQLKit
import Vapor
import XCTest


class ApiTests: AppTestCase {

    func test_version() throws {
        try app.test(.GET, "api/version") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode(API.Version.self),
                           API.Version(version: "dev - will be overriden in release builds"))
        }
    }

    func test_search_noQuery() throws {
        try app.test(.GET, "api/search") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode([API.SearchResult].self), [])
        }
    }

    func test_search_basic_param() throws {
        try app.test(.GET, "api/search?query=foo%20bar") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(
                try res.content.decode([API.SearchResult].self),
                [
                    .init(packageName: "FooBar", repositoryId: "someone/FooBar", summary: "A foo bar repo"),
                    .init(packageName: "BazBaq", repositoryId: "another/barbaq", summary: "Some other repo"),
            ])
        }
    }

    func test_regexClause() throws {
        XCTAssertEqual(
            API.SearchQuery.regexClause("foo"),
            "coalesce(v.package_name) || ' ' || coalesce(r.summary, '') || ' ' || coalesce(r.name, '') || ' ' || coalesce(r.owner, '') ~* 'foo'"
        )
    }

    func test_buildQuery() throws {
        XCTAssertEqual(
            API.SearchQuery.buildQuery(["foo"]),
            API.SearchQuery.preamble + "\nand " + API.SearchQuery.regexClause("foo")
        )
    }

    func test_query() throws {
        // setup
        let p1 = try savePackage(on: app.db, "1")
        let p2 = try savePackage(on: app.db, "2")
        try Repository(package: p1, summary: "some package", defaultBranch: "master").save(on: app.db).wait()
        try Repository(package: p2, summary: "bar", defaultBranch: "master").save(on: app.db).wait()
        try Version(package: p1, reference: .branch("master"), packageName: "Foo").save(on: app.db).wait()
        try Version(package: p2, reference: .branch("master"), packageName: "Bar").save(on: app.db).wait()

        // MUT
        struct Row: Decodable, Equatable {
            var packageName: String

            enum CodingKeys: String, CodingKey {
                case packageName = "package_name"
            }
        }

        let query = (app.db as? SQLDatabase)?.raw(
            .init(API.SearchQuery.buildQuery(["bar"]))
        ).all(decoding: Row.self)
        let res = try query?.wait()

        // validation
        XCTAssertEqual(res, [Row(packageName: "Bar")])
    }
}
