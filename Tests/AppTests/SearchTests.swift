// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@testable import App

import SnapshotTesting
import SQLKit
import XCTVapor


class SearchTests: AppTestCase {
    
    func test_DBRecord_packageURL() throws {
        XCTAssertEqual(Search.DBRecord(matchType: .package,
                                       packageId: UUID(),
                                       repositoryName: "bar",
                                       repositoryOwner: "foo").packageURL,
                       "/foo/bar")
        XCTAssertEqual(Search.DBRecord(matchType: .package,
                                       packageId: UUID(),
                                       repositoryName: "foo bar",
                                       repositoryOwner: "baz").packageURL,
                       "/baz/foo%20bar")
    }

    func test_packageMatchQuery_single_term() throws {
        let b = Search.packageMatchQueryBuilder(on: app.db, terms: ["a"], filters: [])
        XCTAssertEqual(renderSQL(b), #"SELECT DISTINCT 'package' AS "match_type", NULL AS "keyword", "package_id", "package_name", "repo_name", "repo_owner", "score", "summary", "stars", "license", "last_commit_date", "last_activity_at", "keywords", NULL::INT AS "levenshtein_dist", LOWER("package_name") = $1 AS "exact_package_name_match" FROM "search" WHERE CONCAT_WS(' ', "package_name", COALESCE("summary", ''), "repo_name", "repo_owner", ARRAY_TO_STRING("keywords", ' ')) ~* $2 AND "repo_owner" IS NOT NULL AND "repo_name" IS NOT NULL ORDER BY "exact_package_name_match" DESC, "score" DESC, "package_name" ASC"#)
        XCTAssertEqual(binds(b), ["a", "a"])
    }

    func test_packageMatchQuery_multiple_terms() throws {
        let b = Search.packageMatchQueryBuilder(on: app.db, terms: ["a", "b"], filters: [])
        XCTAssertEqual(renderSQL(b), #"SELECT DISTINCT 'package' AS "match_type", NULL AS "keyword", "package_id", "package_name", "repo_name", "repo_owner", "score", "summary", "stars", "license", "last_commit_date", "last_activity_at", "keywords", NULL::INT AS "levenshtein_dist", LOWER("package_name") = $1 AS "exact_package_name_match" FROM "search" WHERE CONCAT_WS(' ', "package_name", COALESCE("summary", ''), "repo_name", "repo_owner", ARRAY_TO_STRING("keywords", ' ')) ~* $2 AND CONCAT_WS(' ', "package_name", COALESCE("summary", ''), "repo_name", "repo_owner", ARRAY_TO_STRING("keywords", ' ')) ~* $3 AND "repo_owner" IS NOT NULL AND "repo_name" IS NOT NULL ORDER BY "exact_package_name_match" DESC, "score" DESC, "package_name" ASC"#)
        XCTAssertEqual(binds(b), ["a b", "a", "b"])
    }

    func test_packageMatchQuery_AuthorSearchFilter() throws {
        let b = Search.packageMatchQueryBuilder(
            on: app.db, terms: ["a"],
            filters: [try AuthorSearchFilter(expression: .init(operator: .is, value: "foo"))]
        )

        XCTAssertEqual(renderSQL(b), """
              SELECT DISTINCT 'package' AS "match_type", NULL AS "keyword", "package_id", "package_name", "repo_name", "repo_owner", "score", "summary", "stars", "license", "last_commit_date", "last_activity_at", "keywords", NULL::INT AS "levenshtein_dist", LOWER("package_name") = $1 AS "exact_package_name_match" FROM "search" WHERE CONCAT_WS(' ', "package_name", COALESCE("summary", ''), "repo_name", "repo_owner", ARRAY_TO_STRING("keywords", ' ')) ~* $2 AND "repo_owner" IS NOT NULL AND "repo_name" IS NOT NULL AND ("repo_owner" ILIKE $3) ORDER BY "exact_package_name_match" DESC, "score" DESC, "package_name" ASC
              """)
        XCTAssertEqual(binds(b), ["a", "a", "foo"])
    }

    func test_packageMatchQuery_KeywordSearchFilter() throws {
        let b = Search.packageMatchQueryBuilder(
            on: app.db, terms: ["a"],
            filters: [try KeywordSearchFilter(expression: .init(operator: .is,
                                                                value: "foo"))]
        )

        XCTAssertEqual(renderSQL(b), """
            SELECT DISTINCT 'package' AS "match_type", NULL AS "keyword", "package_id", "package_name", "repo_name", "repo_owner", "score", "summary", "stars", "license", "last_commit_date", "last_activity_at", "keywords", NULL::INT AS "levenshtein_dist", LOWER("package_name") = $1 AS "exact_package_name_match" FROM "search" WHERE CONCAT_WS(' ', "package_name", COALESCE("summary", ''), "repo_name", "repo_owner", ARRAY_TO_STRING("keywords", ' ')) ~* $2 AND "repo_owner" IS NOT NULL AND "repo_name" IS NOT NULL AND ($3 ILIKE ANY("keywords")) ORDER BY "exact_package_name_match" DESC, "score" DESC, "package_name" ASC
            """)
        XCTAssertEqual(binds(b), ["a", "a", "foo"])
    }

    func test_packageMatchQuery_LastActivitySearchFilter() throws {
        let b = Search.packageMatchQueryBuilder(
            on: app.db, terms: ["a"],
            filters: [try LastActivitySearchFilter(expression: .init(operator: .greaterThan,
                                                                     value: "2021-12-01"))]
        )

        XCTAssertEqual(renderSQL(b), """
            SELECT DISTINCT 'package' AS "match_type", NULL AS "keyword", "package_id", "package_name", "repo_name", "repo_owner", "score", "summary", "stars", "license", "last_commit_date", "last_activity_at", "keywords", NULL::INT AS "levenshtein_dist", LOWER("package_name") = $1 AS "exact_package_name_match" FROM "search" WHERE CONCAT_WS(' ', "package_name", COALESCE("summary", ''), "repo_name", "repo_owner", ARRAY_TO_STRING("keywords", ' ')) ~* $2 AND "repo_owner" IS NOT NULL AND "repo_name" IS NOT NULL AND ("last_activity_at" > $3) ORDER BY "exact_package_name_match" DESC, "score" DESC, "package_name" ASC
            """)
        XCTAssertEqual(binds(b), ["a", "a", "2021-12-01"])
    }

    func test_packageMatchQuery_LastCommitSearchFilter() throws {
        let b = Search.packageMatchQueryBuilder(
            on: app.db, terms: ["a"],
            filters: [try LastCommitSearchFilter(expression: .init(operator: .greaterThan,
                                                                   value: "2021-12-01"))]
        )

        XCTAssertEqual(renderSQL(b), """
            SELECT DISTINCT 'package' AS "match_type", NULL AS "keyword", "package_id", "package_name", "repo_name", "repo_owner", "score", "summary", "stars", "license", "last_commit_date", "last_activity_at", "keywords", NULL::INT AS "levenshtein_dist", LOWER("package_name") = $1 AS "exact_package_name_match" FROM "search" WHERE CONCAT_WS(' ', "package_name", COALESCE("summary", ''), "repo_name", "repo_owner", ARRAY_TO_STRING("keywords", ' ')) ~* $2 AND "repo_owner" IS NOT NULL AND "repo_name" IS NOT NULL AND ("last_commit_date" > $3) ORDER BY "exact_package_name_match" DESC, "score" DESC, "package_name" ASC
            """)
        XCTAssertEqual(binds(b), ["a", "a", "2021-12-01"])
    }

    func test_packageMatchQuery_LicenseSearchFilter() throws {
        let b = Search.packageMatchQueryBuilder(
            on: app.db, terms: ["a"],
            filters: [try LicenseSearchFilter(expression: .init(operator: .is, value: "mit"))]
        )

        XCTAssertEqual(renderSQL(b), """
            SELECT DISTINCT 'package' AS "match_type", NULL AS "keyword", "package_id", "package_name", "repo_name", "repo_owner", "score", "summary", "stars", "license", "last_commit_date", "last_activity_at", "keywords", NULL::INT AS "levenshtein_dist", LOWER("package_name") = $1 AS "exact_package_name_match" FROM "search" WHERE CONCAT_WS(' ', "package_name", COALESCE("summary", ''), "repo_name", "repo_owner", ARRAY_TO_STRING("keywords", ' ')) ~* $2 AND "repo_owner" IS NOT NULL AND "repo_name" IS NOT NULL AND ("license" IN ($3)) ORDER BY "exact_package_name_match" DESC, "score" DESC, "package_name" ASC
            """)
        XCTAssertEqual(binds(b), ["a", "a", "mit"])
    }

    func test_packageMatchQuery_PlatformSearchFilter() throws {
        let b = Search.packageMatchQueryBuilder(
            on: app.db, terms: ["a"],
            filters: [try PlatformSearchFilter(expression: .init(operator: .is, value: "ios,macos"))]
        )

        XCTAssertEqual(renderSQL(b), """
        SELECT DISTINCT 'package' AS "match_type", NULL AS "keyword", "package_id", "package_name", "repo_name", "repo_owner", "score", "summary", "stars", "license", "last_commit_date", "last_activity_at", "keywords", NULL::INT AS "levenshtein_dist", LOWER("package_name") = $1 AS "exact_package_name_match" FROM "search" WHERE CONCAT_WS(' ', "package_name", COALESCE("summary", ''), "repo_name", "repo_owner", ARRAY_TO_STRING("keywords", ' ')) ~* $2 AND "repo_owner" IS NOT NULL AND "repo_name" IS NOT NULL AND ("platform_compatibility" @> $3) ORDER BY "exact_package_name_match" DESC, "score" DESC, "package_name" ASC
        """)
        XCTAssertEqual(binds(b), ["a", "a", "{ios,macos}"])
    }

    func test_packageMatchQuery_ProductTypeSearchFilter() throws {
        for type in ProductTypeSearchFilter.ProductType.allCases {
            let b = Search.packageMatchQueryBuilder(
                on: app.db, terms: ["a"],
                filters: [
                    try ProductTypeSearchFilter(expression: .init(operator: .is, value: type.rawValue))
                ]
            )
            XCTAssertEqual(renderSQL(b), """
            SELECT DISTINCT 'package' AS "match_type", NULL AS "keyword", "package_id", "package_name", "repo_name", "repo_owner", "score", "summary", "stars", "license", "last_commit_date", "last_activity_at", "keywords", NULL::INT AS "levenshtein_dist", LOWER("package_name") = $1 AS "exact_package_name_match" FROM "search" WHERE CONCAT_WS(' ', "package_name", COALESCE("summary", ''), "repo_name", "repo_owner", ARRAY_TO_STRING("keywords", ' ')) ~* $2 AND "repo_owner" IS NOT NULL AND "repo_name" IS NOT NULL AND ("product_type" ? $3) ORDER BY "exact_package_name_match" DESC, "score" DESC, "package_name" ASC
            """)
            XCTAssertEqual(binds(b), ["a", "a", "\(type.rawValue)"])
        }
    }

    func test_packageMatchQuery_StarsSearchFilter() throws {
        let b = Search.packageMatchQueryBuilder(
            on: app.db, terms: ["a"],
            filters: [try StarsSearchFilter(expression: .init(operator: .greaterThan,
                                                              value: "500"))])

        XCTAssertEqual(renderSQL(b), """
            SELECT DISTINCT 'package' AS "match_type", NULL AS "keyword", "package_id", "package_name", "repo_name", "repo_owner", "score", "summary", "stars", "license", "last_commit_date", "last_activity_at", "keywords", NULL::INT AS "levenshtein_dist", LOWER("package_name") = $1 AS "exact_package_name_match" FROM "search" WHERE CONCAT_WS(' ', "package_name", COALESCE("summary", ''), "repo_name", "repo_owner", ARRAY_TO_STRING("keywords", ' ')) ~* $2 AND "repo_owner" IS NOT NULL AND "repo_name" IS NOT NULL AND ("stars" > $3) ORDER BY "exact_package_name_match" DESC, "score" DESC, "package_name" ASC
            """)
        XCTAssertEqual(binds(b), ["a", "a", "500"])
    }

    func test_keywordMatchQuery_single_term() throws {
        let b = Search.keywordMatchQueryBuilder(on: app.db, terms: ["a"])
        XCTAssertEqual(renderSQL(b), #"SELECT DISTINCT 'keyword' AS "match_type", "keyword", NULL::UUID AS "package_id", NULL AS "package_name", NULL AS "repo_name", NULL AS "repo_owner", NULL::INT AS "score", NULL AS "summary", NULL::INT AS "stars", NULL AS "license", NULL::TIMESTAMP AS "last_commit_date", NULL::TIMESTAMP AS "last_activity_at", NULL::TEXT[] AS "keywords", LEVENSHTEIN("keyword", $1) AS "levenshtein_dist", NULL::BOOL AS "exact_package_name_match" FROM "search", UNNEST("keywords") AS "keyword" WHERE "keyword" ILIKE $2 ORDER BY "levenshtein_dist" LIMIT 50"#)
        XCTAssertEqual(binds(b), ["a", "%a%"])
    }

    func test_keywordMatchQuery_multiple_terms() throws {
        let b = Search.keywordMatchQueryBuilder(on: app.db, terms: ["a", "b"])
        XCTAssertEqual(renderSQL(b), #"SELECT DISTINCT 'keyword' AS "match_type", "keyword", NULL::UUID AS "package_id", NULL AS "package_name", NULL AS "repo_name", NULL AS "repo_owner", NULL::INT AS "score", NULL AS "summary", NULL::INT AS "stars", NULL AS "license", NULL::TIMESTAMP AS "last_commit_date", NULL::TIMESTAMP AS "last_activity_at", NULL::TEXT[] AS "keywords", LEVENSHTEIN("keyword", $1) AS "levenshtein_dist", NULL::BOOL AS "exact_package_name_match" FROM "search", UNNEST("keywords") AS "keyword" WHERE "keyword" ILIKE $2 ORDER BY "levenshtein_dist" LIMIT 50"#)
        XCTAssertEqual(binds(b), ["a b", "%a b%"])
    }

    func test_authorMatchQuery_single_term() throws {
        let b = Search.authorMatchQueryBuilder(on: app.db, terms: ["a"])
        XCTAssertEqual(renderSQL(b), #"SELECT DISTINCT 'author' AS "match_type", NULL AS "keyword", NULL::UUID AS "package_id", NULL AS "package_name", NULL AS "repo_name", "repo_owner", NULL::INT AS "score", NULL AS "summary", NULL::INT AS "stars", NULL AS "license", NULL::TIMESTAMP AS "last_commit_date", NULL::TIMESTAMP AS "last_activity_at", NULL::TEXT[] AS "keywords", LEVENSHTEIN("repo_owner", $1) AS "levenshtein_dist", NULL::BOOL AS "exact_package_name_match" FROM "search" WHERE "repo_owner" ILIKE $2 ORDER BY "levenshtein_dist" LIMIT 50"#)
        XCTAssertEqual(binds(b), ["a", "%a%"])
    }

    func test_authorMatchQuery_multiple_term() throws {
        let b = Search.authorMatchQueryBuilder(on: app.db, terms: ["a", "b"])
        XCTAssertEqual(renderSQL(b), #"SELECT DISTINCT 'author' AS "match_type", NULL AS "keyword", NULL::UUID AS "package_id", NULL AS "package_name", NULL AS "repo_name", "repo_owner", NULL::INT AS "score", NULL AS "summary", NULL::INT AS "stars", NULL AS "license", NULL::TIMESTAMP AS "last_commit_date", NULL::TIMESTAMP AS "last_activity_at", NULL::TEXT[] AS "keywords", LEVENSHTEIN("repo_owner", $1) AS "levenshtein_dist", NULL::BOOL AS "exact_package_name_match" FROM "search" WHERE "repo_owner" ILIKE $2 ORDER BY "levenshtein_dist" LIMIT 50"#)
        XCTAssertEqual(binds(b), ["a b", "%a b%"])
    }

    func test_query_sql() throws {
        // Test to confirm shape of rendered search SQL
        // MUT
        let query = try XCTUnwrap(Search.query(app.db, ["test"], page: 1, pageSize: 20))
        // validate
        XCTAssertEqual(renderSQL(query), """
            SELECT * FROM ((SELECT DISTINCT 'author' AS "match_type", NULL AS "keyword", NULL::UUID AS "package_id", NULL AS "package_name", NULL AS "repo_name", "repo_owner", NULL::INT AS "score", NULL AS "summary", NULL::INT AS "stars", NULL AS "license", NULL::TIMESTAMP AS "last_commit_date", NULL::TIMESTAMP AS "last_activity_at", NULL::TEXT[] AS "keywords", LEVENSHTEIN("repo_owner", $1) AS "levenshtein_dist", NULL::BOOL AS "exact_package_name_match" FROM "search" WHERE "repo_owner" ILIKE $2 ORDER BY "levenshtein_dist" LIMIT 50) UNION ALL (SELECT DISTINCT 'keyword' AS "match_type", "keyword", NULL::UUID AS "package_id", NULL AS "package_name", NULL AS "repo_name", NULL AS "repo_owner", NULL::INT AS "score", NULL AS "summary", NULL::INT AS "stars", NULL AS "license", NULL::TIMESTAMP AS "last_commit_date", NULL::TIMESTAMP AS "last_activity_at", NULL::TEXT[] AS "keywords", LEVENSHTEIN("keyword", $3) AS "levenshtein_dist", NULL::BOOL AS "exact_package_name_match" FROM "search", UNNEST("keywords") AS "keyword" WHERE "keyword" ILIKE $4 ORDER BY "levenshtein_dist" LIMIT 50) UNION ALL (SELECT DISTINCT 'package' AS "match_type", NULL AS "keyword", "package_id", "package_name", "repo_name", "repo_owner", "score", "summary", "stars", "license", "last_commit_date", "last_activity_at", "keywords", NULL::INT AS "levenshtein_dist", LOWER("package_name") = $5 AS "exact_package_name_match" FROM "search" WHERE CONCAT_WS(' ', "package_name", COALESCE("summary", ''), "repo_name", "repo_owner", ARRAY_TO_STRING("keywords", ' ')) ~* $6 AND "repo_owner" IS NOT NULL AND "repo_name" IS NOT NULL ORDER BY "exact_package_name_match" DESC, "score" DESC, "package_name" ASC LIMIT 21 OFFSET 0)) AS "t"
            """)
        XCTAssertEqual(binds(query), ["test", "%test%", "test", "%test%", "test", "test"])
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
                       lastCommitDate: .t0,
                       name: "name 2",
                       owner: "owner 2",
                       stars: 1234,
                       summary: "bar package").save(on: app.db).wait()
        try Version(package: p1, packageName: "Foo", reference: .branch("main")).save(on: app.db).wait()
        try Version(package: p2, packageName: "Bar", reference: .branch("main")).save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()
        
        // MUT
        let res = try Search.fetch(app.db, ["bar"], page: 1, pageSize: 20).wait()
        
        // validation
        XCTAssertEqual(res,
                       .init(hasMoreResults: false,
                             searchTerm: "bar",
                             searchFilters: [],
                             results: [
                                .package(
                                    .init(packageId: try p2.requireID(),
                                          packageName: "Bar",
                                          packageURL: "/owner%202/name%202",
                                          repositoryName: "name 2",
                                          repositoryOwner: "owner 2",
                                          stars: 1234,
                                          lastActivityAt: .t0,
                                          summary: "bar package",
                                          keywords: [])!
                                )
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
                       lastCommitDate: .t0,
                       name: "package 2",
                       owner: "owner",
                       stars: 1234,
                       summary: "package 2 description").save(on: app.db).wait()
        try Version(package: p1, packageName: "Foo", reference: .branch("main")).save(on: app.db).wait()
        try Version(package: p2, packageName: "Bar", reference: .branch("main")).save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()
        
        // MUT
        let res = try Search.fetch(app.db, ["owner", "bar"], page: 1, pageSize: 20).wait()
        
        // validation
        XCTAssertEqual(res,
                       .init(hasMoreResults: false,
                             searchTerm: "owner bar",
                             searchFilters: [],
                             results: [
                                .package(
                                    .init(packageId: try p2.requireID(),
                                          packageName: "Bar",
                                          packageURL: "/owner/package%202",
                                          repositoryName: "package 2",
                                          repositoryOwner: "owner",
                                          stars: 1234,
                                          lastActivityAt: .t0,
                                          summary: "package 2 description",
                                          keywords: [])!
                                )
                             ])
        )
    }

    func test_fetch_distinct() async throws {
        // Ensure we de-duplicate results
        // setup
        let p = Package.init(id: .id0, url: "bar".url)
        try await p.save(on: app.db)
        try await Repository(package: p,
                             defaultBranch: "main",
                             name: "bar",
                             owner: "foo").save(on: app.db)
        let v = try Version(package: p)
        try await v.save(on: app.db)
        try await Product(version: v, type: .library(.automatic), name: "lib").save(on: app.db)
        try await Product(version: v, type: .plugin, name: "plugin").save(on: app.db)
        try await Search.refresh(on: app.db).get()

        // MUT
        let res = try await Search.fetch(app.db, ["bar"], page: 1, pageSize: 20).get()

        // validate
        XCTAssertEqual(res.results.count, 1)
        XCTAssertEqual(res.results.compactMap(\.packageResult?.repositoryName), ["bar"])
    }
    
    func test_quoting() throws {
        // Test searching for a `'`
        // setup
        let p1 = try savePackage(on: app.db, "1")
        let p2 = try savePackage(on: app.db, "2")
        try Repository(package: p1,
                       defaultBranch: "main",
                       lastCommitDate: .t0,
                       name: "name 1",
                       owner: "owner 1",
                       stars: 1234,
                       summary: "some 'package'").save(on: app.db).wait()
        try Repository(package: p2,
                       defaultBranch: "main",
                       lastCommitDate: .t0,
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
                             searchTerm: "'",
                             searchFilters: [],
                             results: [
                                .package(
                                    .init(packageId: try p1.requireID(),
                                          packageName: "Foo",
                                          packageURL: "/owner%201/name%201",
                                          repositoryName: "name 1",
                                          repositoryOwner: "owner 1",
                                          stars: 1234,
                                          lastActivityAt: .t0,
                                          summary: "some 'package'",
                                          keywords: [])!
                                    )
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
                                          name: $0.url, owner: "foobar") }
            .save(on: app.db)
            .wait()
        try packages.map { try Version(package: $0, packageName: $0.url, reference: .branch("default")) }
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
            XCTAssertEqual(res.results.map(\.testDescription),
                           ["a:foobar", "p:0", "p:1", "p:2"])
        }

        do {  // second page
            // MUT
            let res = try API.search(database: app.db,
                                     query: "foo",
                                     page: 2,
                                     pageSize: 3).wait()

            // validate
            XCTAssertTrue(res.hasMoreResults)
            XCTAssertEqual(res.results.map(\.testDescription),
                           ["p:3", "p:4", "p:5"])
        }

        do {  // third page
            // MUT
            let res = try API.search(database: app.db,
                                     query: "foo",
                                     page: 3,
                                     pageSize: 3).wait()

            // validate
            XCTAssertFalse(res.hasMoreResults)
            XCTAssertEqual(res.results.map(\.testDescription),
                           ["p:6", "p:7", "p:8"])
        }
    }

    func test_search_pagination_with_author_keyword_results() throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1198
        // setup
        let packages = (0..<9).map { idx in
            Package(url: "\(idx)".url, score: 15 - idx)
        }
        try packages.save(on: app.db).wait()
        try packages.map { try Repository(package: $0,
                                          defaultBranch: "default",
                                          keywords: ["foo"],
                                          name: $0.url,
                                          owner: "foobar") }
            .save(on: app.db)
            .wait()
        try packages.map { try Version(package: $0, packageName: $0.url, reference: .branch("default")) }
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
            XCTAssertEqual(res.results.map(\.testDescription),
                           ["a:foobar", "k:foo", "p:0", "p:1", "p:2"])
        }

        do {  // second page
            // MUT
            let res = try API.search(database: app.db,
                                     query: "foo",
                                     page: 2,
                                     pageSize: 3).wait()

            // validate
            XCTAssertTrue(res.hasMoreResults)
            XCTAssertEqual(res.results.map(\.testDescription),
                           ["p:3", "p:4", "p:5"])
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
                                          name: $0.url, owner: "foobar") }
            .save(on: app.db)
            .wait()
        try packages.map { try Version(package: $0, packageName: $0.url, reference: .branch("default")) }
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
            XCTAssertEqual(res.results.map(\.package?.repositoryName),
                           [])
        }

        do {  // page out of bounds (too small - will be clamped to page 1)
            // MUT
            let res = try API.search(database: app.db,
                                     query: "foo",
                                     page: 0,
                                     pageSize: 3).wait()
            XCTAssertTrue(res.hasMoreResults)
            XCTAssertEqual(res.results.map(\.testDescription),
                           ["a:foobar", "p:0", "p:1", "p:2"])
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
                           owner: "foobar",
                           summary: "\($0)").save(on: app.db).wait()
            try Version(package: p, packageName: "\($0)", reference: .branch("main")).save(on: app.db).wait()
        }
        try Search.refresh(on: app.db).wait()
        
        // MUT
        let res = try Search.fetch(app.db, ["foo"], page: 1, pageSize: 20).wait()
        
        // validation
        XCTAssertEqual(res.results.count, 11)
        XCTAssertEqual(res.results.map(\.testDescription),
                       ["a:foobar", "p:9", "p:8", "p:7", "p:6", "p:5", "p:4", "p:3", "p:2", "p:1", "p:0"])
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
        
        XCTAssertEqual(res.results.map(\.package?.repositoryName),
                       ["1", "3", "2"])
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
        
        XCTAssertEqual(res.results.map(\.package?.repositoryName),
                       ["1", "3", "2"])
    }
    
    func test_exclude_null_fields() throws {
        // Ensure excluding results with NULL fields
        // setup:
        // Packages that all match but each having one NULL for a required field
        let p1 = Package(id: UUID(), url: "1", score: 10)
        let p2 = Package(id: UUID(), url: "2", score: 20)
        try [p1, p2].save(on: app.db).wait()
        try Repository(package: p1,
                       defaultBranch: "main",
                       name: nil, // Missing repository name
                       owner: "foobar",
                       summary: "").save(on: app.db).wait()
        try Repository(package: p2,
                       defaultBranch: "main",
                       name: "2",
                       owner: nil, // Missing repository owner
                       summary: "foo bar").save(on: app.db).wait()
        try Version(package: p1, packageName: "foo1", reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: p2, packageName: "foo2", reference: .branch("main"))
            .save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()
        
        // MUT
        let res = try Search.fetch(app.db, ["foo"], page: 1, pageSize: 20).wait()

        // ensure only the author result is coming through, not the packages
        XCTAssertEqual(res.results.map(\.testDescription), ["a:foobar"])
    }

    func test_include_null_package_name() throws {
        // Ensure that packages that somehow have a NULL package name do *not* get excluded from search results.
        let p1 = Package(id: .id0, url: "1", score: 10)
        try p1.save(on: app.db).wait()

        try Repository(package: p1,
                       defaultBranch: "main",
                       name: "1",
                       owner: "bar",
                       summary: "foo and bar").save(on: app.db).wait()

        // Version record with a missing package name.
        try Version(package: p1, packageName: nil, reference: .branch("main"))
            .save(on: app.db).wait()

        try Search.refresh(on: app.db).wait()

        // MUT
        let res = try Search.fetch(app.db, ["foo"], page: 1, pageSize: 20).wait()

        let packageResult = try res.results.first.unwrap().package.unwrap()
        XCTAssertEqual(packageResult.packageId, .id0)
        XCTAssertEqual(packageResult.repositoryName, "1")
        XCTAssertEqual(packageResult.repositoryOwner, "bar")
        XCTAssertEqual(packageResult.packageName, nil)
    }

    func test_sanitize() throws {
        XCTAssertEqual(Search.sanitize(["*"]), ["\\*"])
        XCTAssertEqual(Search.sanitize(["?"]), ["\\?"])
        XCTAssertEqual(Search.sanitize(["("]), ["\\("])
        XCTAssertEqual(Search.sanitize([")"]), ["\\)"])
        XCTAssertEqual(Search.sanitize(["["]), ["\\["])
        XCTAssertEqual(Search.sanitize(["]"]), ["\\]"])
        XCTAssertEqual(Search.sanitize(["\\"]), [])
        XCTAssertEqual(Search.sanitize(["test\\"]), ["test"])
    }

    func test_invalid_characters() throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/974
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1402
        // Ensure we don't raise a 500 for certain characters
        // "server: invalid regular expression: quantifier operand invalid"

        do {
            // MUT
            let res = try Search.fetch(app.db, ["*"], page: 1, pageSize: 20).wait()

            // validation
            XCTAssertEqual(res, .init(hasMoreResults: false, searchTerm: "\\*", searchFilters: [], results: []))
        }

        do {
            // MUT
            let res = try Search.fetch(app.db, ["\\"], page: 1, pageSize: 20).wait()

            // validation
            XCTAssertEqual(res, .init(hasMoreResults: false, searchTerm: "", searchFilters: [], results: []))
        }
    }

    func test_search_keyword() async throws {
        // Test searching for a keyword
        // setup
        // p1: decoy
        // p2: match
        let pkgs = (0..<2).map { Package(id: UUID(), url: "\($0)".url) }
        try await pkgs.save(on: app.db)
        try await [
            Repository(package: pkgs[0],
                       defaultBranch: "main",
                       name: "0",
                       owner: "foo"),
            Repository(package: pkgs[1],
                       defaultBranch: "main",
                       keywords: ["topic"],
                       name: "1",
                       owner: "foo")
        ].save(on: app.db)
        try await [
            Version(package: pkgs[0], packageName: "p0", reference: .branch("main")),
            Version(package: pkgs[1], packageName: "p1", reference: .branch("main"))
        ].save(on: app.db)
        try await Search.refresh(on: app.db).get()

        // MUT
        let res = try await Search.fetch(app.db, ["topic"], page: 1, pageSize: 20).get()

        XCTAssertEqual(res.results.map(\.testDescription), ["k:topic", "p:p1"])
    }

    func test_search_keyword_multiple_results() async throws {
        // Test searching with multiple keyword results
        // setup
        // p1: decoy
        // p2: match
        let pkgs = (0..<4).map { Package(id: UUID(), url: "\($0)".url, score: $0) }
        try await pkgs.save(on: app.db)
        let keywords = [
            [],
            ["topic"],
            ["atopicb"],
            ["topicb"],
        ]
        try await (0..<4).map {
            try Repository(package: pkgs[$0],
                           defaultBranch: "main",
                           keywords: keywords[$0],
                           name: "\($0)",
                           owner: "foo")
        }.save(on: app.db)
        try await (0..<4).map {
            try Version(package: pkgs[$0], packageName: "p\($0)", reference: .branch("main"))
        }.save(on: app.db)
        try await Search.refresh(on: app.db).get()

        // MUT
        let res = try await Search.fetch(app.db, ["topic"], page: 1, pageSize: 20).get()

        // validate that keyword results are ordered by levenshtein distance
        // (packages are also matched via their keywords)
        XCTAssertEqual(res.results.map(\.testDescription),
                       ["k:topic", "k:topicb", "k:atopicb", "p:p3", "p:p2", "p:p1"])
    }

    func test_search_author_multiple_results() async throws {
        // Test searching with multiple authors results
        // setup
        // p1: decoy
        // p2: match
        let pkgs = (0..<4).map {
            Package(id: UUID(), url: "\($0)".url, score: $0)
        }
        try await pkgs.save(on: app.db)
        let authors = [
            "some-other",
            "another-author",
            "author",
            "author-2",
        ]
        try await (0..<4).map {
            try Repository(package: pkgs[$0],
                           defaultBranch: "main",
                           name: "\($0)",
                           owner: authors[$0])
        }.save(on: app.db)
        try await (0..<4).map {
            try Version(package: pkgs[$0], packageName: "p\($0)", reference: .branch("main"))
        }.save(on: app.db)
        try await Search.refresh(on: app.db).get()

        // MUT
        let res = try await Search.fetch(app.db, ["author"], page: 1, pageSize: 20).get()

        // validate that keyword results are ordered by levenshtein distance
        // (packages are also matched via their keywords)
        XCTAssertEqual(res.results.map(\.testDescription),
                       ["a:author", "a:author-2", "a:another-author", "p:p3", "p:p2", "p:p1"])
    }

    func test_search_author() throws {
        // Test searching for an author
        // setup
        // p1: decoy
        // p2: match
        let p1 = Package(id: .id1, url: "1", score: 10)
        let p2 = Package(id: .id2, url: "2", score: 20)
        try [p1, p2].save(on: app.db).wait()
        try Repository(package: p1,
                       defaultBranch: "main",
                       name: "1",
                       owner: "bar",
                       summary: "").save(on: app.db).wait()
        try Repository(package: p2,
                       defaultBranch: "main",
                       lastCommitDate: .t0,
                       name: "2",
                       owner: "foo",
                       stars: 1234,
                       summary: "").save(on: app.db).wait()
        try Version(package: p1, packageName: "p1", reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: p2, packageName: "p2", reference: .branch("main"))
            .save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()

        // MUT
        let res = try Search.fetch(app.db, ["foo"], page: 1, pageSize: 20).wait()

        XCTAssertEqual(res.results, [
            .author(.init(name: "foo")),
            // the owner fields is part of the package match, so we always also match packages by an author when searching for an author
            .package(.init(packageId: .id2,
                           packageName: "p2",
                           packageURL: "/foo/2",
                           repositoryName: "2",
                           repositoryOwner: "foo",
                           stars: 1234,
                           lastActivityAt: .t0,
                           summary: "",
                           keywords: [])!)
        ])
    }
    
    func test_search_withNoTerms() throws {
        // Setup
        let p1 = Package(id: .id1, url: "1", score: 10)
        let p2 = Package(id: .id2, url: "2", score: 20)
        try [p1, p2].save(on: app.db).wait()
        try Repository(package: p1,
                       defaultBranch: "main",
                       keywords: ["a"],
                       name: "1",
                       owner: "bar",
                       stars: 50,
                       summary: "test package").save(on: app.db).wait()
        try Repository(package: p2,
                       defaultBranch: "main",
                       keywords: ["b"],
                       name: "2",
                       owner: "foo",
                       stars: 10,
                       summary: "test package").save(on: app.db).wait()
        try Version(package: p1, packageName: "p1", reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: p2, packageName: "p2", reference: .branch("main"))
            .save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()
        
        // MUT
        let res = try Search.fetch(app.db, ["stars:>15"], page: 1, pageSize: 20).wait()
        XCTAssertEqual(res.results.count, 1)
        XCTAssertEqual(res.results.compactMap(\.package).compactMap(\.packageName).sorted(), ["p1"])
    }
    
    func test_search_withFilter_stars() throws {
        // Setup
        let p1 = Package(id: .id1, url: "1", score: 10)
        let p2 = Package(id: .id2, url: "2", score: 20)
        try [p1, p2].save(on: app.db).wait()
        try Repository(package: p1,
                       defaultBranch: "main",
                       name: "1",
                       owner: "bar",
                       stars: 50,
                       summary: "test package").save(on: app.db).wait()
        try Repository(package: p2,
                       defaultBranch: "main",
                       name: "2",
                       owner: "foo",
                       stars: 10,
                       summary: "test package").save(on: app.db).wait()
        try Version(package: p1, packageName: "p1", reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: p2, packageName: "p2", reference: .branch("main"))
            .save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()
        
        do { // Baseline
            let res = try Search.fetch(app.db, ["test"], page: 1, pageSize: 20).wait()
            XCTAssertEqual(res.results.count, 2)
            XCTAssertEqual(res.results.compactMap(\.package).compactMap(\.packageName).sorted(), ["p1", "p2"])
        }
        
        do { // Greater Than
            let res = try Search.fetch(app.db, ["test", "stars:>25"], page: 1, pageSize: 20).wait()
            XCTAssertEqual(res.results.count, 1)
            XCTAssertEqual(res.results.first?.package?.packageName, "p1")
        }
        
        do { // Less Than
            let res = try Search.fetch(app.db, ["test", "stars:<25"], page: 1, pageSize: 20).wait()
            XCTAssertEqual(res.results.count, 1)
            XCTAssertEqual(res.results.first?.package?.packageName, "p2")
        }
        
        do { // Equal
            let res = try Search.fetch(app.db, ["test", "stars:50"], page: 1, pageSize: 20).wait()
            XCTAssertEqual(res.results.count, 1)
            XCTAssertEqual(res.results.first?.package?.packageName, "p1")
        }
        
        do { // Not Equals
            let res = try Search.fetch(app.db, ["test", "stars:!50"], page: 1, pageSize: 20).wait()
            XCTAssertEqual(res.results.count, 1)
            XCTAssertEqual(res.results.first?.package?.packageName, "p2")
        }
    }
    
    func test_onlyPackageResults_whenFiltersApplied() throws {
        do { // with filter
            let query = try XCTUnwrap(Search.query(app.db, ["a", "stars:500"], page: 1, pageSize: 5))
            let sql = renderSQL(query)
            XCTAssertTrue(sql.contains(#"SELECT DISTINCT 'author' AS "match_type""#))
            XCTAssertTrue(sql.contains(#"SELECT DISTINCT 'keyword' AS "match_type""#))
            XCTAssertTrue(sql.contains(#"SELECT DISTINCT 'package' AS "match_type""#))
        }
        
        do { // without filter
            let query = try XCTUnwrap(Search.query(app.db, ["a"], page: 1, pageSize: 5))
            let sql = renderSQL(query)
            XCTAssertTrue(sql.contains(#"SELECT DISTINCT 'author' AS "match_type""#))
            XCTAssertTrue(sql.contains(#"SELECT DISTINCT 'keyword' AS "match_type""#))
            XCTAssertTrue(sql.contains(#"SELECT DISTINCT 'package' AS "match_type""#))
        }
    }

    func test_authorSearchFilter() throws {
        // Setup
        let p1 = Package(url: "1", platformCompatibility: [.ios])
        let p2 = Package(url: "2", platformCompatibility: [.macos])
        try [p1, p2].save(on: app.db).wait()
        try Repository(package: p1,
                       defaultBranch: "main",
                       name: "1",
                       owner: "foo",
                       summary: "test package").save(on: app.db).wait()
        try Repository(package: p2,
                       defaultBranch: "main",
                       name: "2",
                       owner: "bar",
                       summary: "test package").save(on: app.db).wait()
        try Version(package: p1, packageName: "p1", reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: p2, packageName: "p2", reference: .branch("main"))
            .save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()

        do {
            // MUT
            let res = try Search.fetch(app.db, ["test", "author:foo"], page: 1, pageSize: 20).wait()

            // validate
            XCTAssertEqual(res.results.compactMap(\.packageResult?.repositoryName), ["1"])
        }

        do {  // double check that leaving the filter term off selects both packages
            // MUT
            let res = try Search.fetch(app.db, ["test"], page: 1, pageSize: 20).wait()

            // validate
            XCTAssertEqual(
                res.results.compactMap(\.packageResult?.repositoryName).sorted(),
                ["1", "2"]
            )
        }
    }

    func test_keywordSearchFilter() throws {
        // Setup
        let p1 = Package(url: "1", platformCompatibility: [.ios])
        let p2 = Package(url: "2", platformCompatibility: [.macos])
        try [p1, p2].save(on: app.db).wait()
        try Repository(package: p1,
                       defaultBranch: "main",
                       keywords: ["kw1", "kw2"],
                       name: "1",
                       owner: "foo",
                       summary: "test package").save(on: app.db).wait()
        try Repository(package: p2,
                       defaultBranch: "main",
                       keywords: ["kw1-2"],
                       name: "2",
                       owner: "bar",
                       summary: "test package").save(on: app.db).wait()
        try Version(package: p1, packageName: "p1", reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: p2, packageName: "p2", reference: .branch("main"))
            .save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()

        do {
            // MUT
            let res = try Search.fetch(app.db, ["test", "keyword:kw1"], page: 1, pageSize: 20).wait()

            // validate
            XCTAssertEqual(res.results.compactMap(\.packageResult?.repositoryName), ["1"])
        }

        do {  // double check that leaving the filter term off selects both packages
            // MUT
            let res = try Search.fetch(app.db, ["test"], page: 1, pageSize: 20).wait()

            // validate
            XCTAssertEqual(
                res.results.compactMap(\.packageResult?.repositoryName).sorted(),
                ["1", "2"]
            )
        }
    }

    func test_lastActivitySearchFilter() throws {
        // Setup
        let p1 = Package(url: "1", platformCompatibility: [.ios])
        let p2 = Package(url: "2", platformCompatibility: [.macos])
        try [p1, p2].save(on: app.db).wait()
        try Repository(package: p1,
                       defaultBranch: "main",
                       lastCommitDate: .t0.addingDays(-1),
                       name: "1",
                       owner: "foo",
                       summary: "test package").save(on: app.db).wait()
        try Repository(package: p2,
                       defaultBranch: "main",
                       lastCommitDate: .t0,
                       name: "2",
                       owner: "bar",
                       summary: "test package").save(on: app.db).wait()
        try Version(package: p1, packageName: "p1", reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: p2, packageName: "p2", reference: .branch("main"))
            .save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()

        do {
            // MUT
            let res = try Search.fetch(app.db, ["test", "last_activity:<1970-01-01"], page: 1, pageSize: 20).wait()

            // validate
            XCTAssertEqual(res.results.compactMap(\.packageResult?.repositoryName), ["1"])
        }

        do {  // double check that leaving the filter term off selects both packages
            // MUT
            let res = try Search.fetch(app.db, ["test"], page: 1, pageSize: 20).wait()

            // validate
            XCTAssertEqual(
                res.results.compactMap(\.packageResult?.repositoryName).sorted(),
                ["1", "2"]
            )
        }
    }

    func test_lastCommitSearchFilter() throws {
        // Setup
        let p1 = Package(url: "1", platformCompatibility: [.ios])
        let p2 = Package(url: "2", platformCompatibility: [.macos])
        try [p1, p2].save(on: app.db).wait()
        try Repository(package: p1,
                       defaultBranch: "main",
                       lastCommitDate: .t0.addingDays(-1),
                       name: "1",
                       owner: "foo",
                       summary: "test package").save(on: app.db).wait()
        try Repository(package: p2,
                       defaultBranch: "main",
                       lastCommitDate: .t0,
                       name: "2",
                       owner: "bar",
                       summary: "test package").save(on: app.db).wait()
        try Version(package: p1, packageName: "p1", reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: p2, packageName: "p2", reference: .branch("main"))
            .save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()

        do {
            // MUT
            let res = try Search.fetch(app.db, ["test", "last_commit:<1970-01-01"], page: 1, pageSize: 20).wait()

            // validate
            XCTAssertEqual(res.results.compactMap(\.packageResult?.repositoryName), ["1"])
        }

        do {  // double check that leaving the filter term off selects both packages
            // MUT
            let res = try Search.fetch(app.db, ["test"], page: 1, pageSize: 20).wait()

            // validate
            XCTAssertEqual(
                res.results.compactMap(\.packageResult?.repositoryName).sorted(),
                ["1", "2"]
            )
        }
    }

    func test_licenseSearchFilter() throws {
        // Setup
        let p1 = Package(url: "1", platformCompatibility: [.ios])
        let p2 = Package(url: "2", platformCompatibility: [.macos])
        try [p1, p2].save(on: app.db).wait()
        try Repository(package: p1,
                       defaultBranch: "main",
                       license: .mit,
                       name: "1",
                       owner: "foo",
                       summary: "test package").save(on: app.db).wait()
        try Repository(package: p2,
                       defaultBranch: "main",
                       license: .none,
                       name: "2",
                       owner: "bar",
                       summary: "test package").save(on: app.db).wait()
        try Version(package: p1, packageName: "p1", reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: p2, packageName: "p2", reference: .branch("main"))
            .save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()

        do {
            // MUT
            let res = try Search.fetch(app.db, ["test", "license:mit"], page: 1, pageSize: 20).wait()

            // validate
            XCTAssertEqual(res.results.compactMap(\.packageResult?.repositoryName), ["1"])
        }

        do {
            // MUT
            let res = try Search.fetch(app.db, ["test", "license:compatible"], page: 1, pageSize: 20).wait()

            // validate
            XCTAssertEqual(res.results.compactMap(\.packageResult?.repositoryName), ["1"])
        }

        do {  // double check that leaving the filter term off selects both packages
            // MUT
            let res = try Search.fetch(app.db, ["test"], page: 1, pageSize: 20).wait()

            // validate
            XCTAssertEqual(
                res.results.compactMap(\.packageResult?.repositoryName).sorted(),
                ["1", "2"]
            )
        }
    }

    func test_platformSearchFilter() throws {
        // Setup
        let p1 = Package(url: "1", platformCompatibility: [.ios])
        let p2 = Package(url: "2", platformCompatibility: [.macos])
        try [p1, p2].save(on: app.db).wait()
        try Repository(package: p1,
                       defaultBranch: "main",
                       name: "1",
                       owner: "foo",
                       summary: "test package").save(on: app.db).wait()
        try Repository(package: p2,
                       defaultBranch: "main",
                       name: "2",
                       owner: "foo",
                       summary: "test package").save(on: app.db).wait()
        try Version(package: p1, packageName: "p1", reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: p2, packageName: "p2", reference: .branch("main"))
            .save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()

        do {
            // MUT
            let res = try Search.fetch(app.db, ["test", "platform:ios"], page: 1, pageSize: 20).wait()

            // validate
            XCTAssertEqual(res.results.compactMap(\.packageResult?.repositoryName), ["1"])
        }

        do {  // double check that leaving the filter term off selects both packages
            // MUT
            let res = try Search.fetch(app.db, ["test"], page: 1, pageSize: 20).wait()

            // validate
            XCTAssertEqual(
                res.results.compactMap(\.packageResult?.repositoryName).sorted(),
                ["1", "2"]
            )
        }
    }

    func test_starsSearchFilter() throws {
        // Setup
        let p1 = Package(url: "1", platformCompatibility: [.ios])
        let p2 = Package(url: "2", platformCompatibility: [.macos])
        try [p1, p2].save(on: app.db).wait()
        try Repository(package: p1,
                       defaultBranch: "main",
                       name: "1",
                       owner: "foo",
                       stars: 10,
                       summary: "test package").save(on: app.db).wait()
        try Repository(package: p2,
                       defaultBranch: "main",
                       name: "2",
                       owner: "bar",
                       summary: "test package").save(on: app.db).wait()
        try Version(package: p1, packageName: "p1", reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: p2, packageName: "p2", reference: .branch("main"))
            .save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()

        do {
            // MUT
            let res = try Search.fetch(app.db, ["test", "stars:>5"], page: 1, pageSize: 20).wait()

            // validate
            XCTAssertEqual(res.results.compactMap(\.packageResult?.repositoryName), ["1"])
        }

        do {  // double check that leaving the filter term off selects both packages
            // MUT
            let res = try Search.fetch(app.db, ["test"], page: 1, pageSize: 20).wait()

            // validate
            XCTAssertEqual(
                res.results.compactMap(\.packageResult?.repositoryName).sorted(),
                ["1", "2"]
            )
        }
    }

    func test_productTypeFilter() async throws {
        // setup
        do {
            let p1 = Package.init(id: .id0, url: "1".url)
            try await p1.save(on: app.db)
            try await Repository(package: p1,
                                 defaultBranch: "main",
                                 name: "1",
                                 owner: "foo",
                                 stars: 1,
                                 summary: "test package").save(on: app.db)
            let v = try Version(package: p1)
            try await v.save(on: app.db)
            try await Product(version: v, type: .library(.automatic), name: "lib").save(on: app.db)
        }
        do {
            let p2 = Package.init(id: .id1, url: "2".url)
            try await p2.save(on: app.db)
            try await Repository(package: p2,
                                 defaultBranch: "main",
                                 name: "2",
                                 owner: "foo",
                                 summary: "test package").save(on: app.db)
            let v = try Version(package: p2)
            try await v.save(on: app.db)
            try await Product(version: v, type: .plugin, name: "plugin").save(on: app.db)
        }
        try await Search.refresh(on: app.db).get()

        do {
            // MUT
            let res = try await Search.fetch(app.db, ["test", "product:plugin"], page: 1, pageSize: 20).get()

            // validate
            XCTAssertEqual(res.results.count, 1)
            XCTAssertEqual(
                res.results.compactMap(\.packageResult?.repositoryName), ["2"]
            )
        }

        do {
            // MUT
            let res = try await Search.fetch(app.db, ["test"], page: 1, pageSize: 20).get()

            // validate
            XCTAssertEqual(res.results.count, 2)
            XCTAssertEqual(
                res.results.compactMap(\.packageResult?.repositoryName), ["1", "2"]
            )
        }
    }

    func test_SearchFilter_error() throws {
        // Test error handling in case of an invalid filter
        // Setup
        let p1 = Package(url: "1", platformCompatibility: [.ios])
        let p2 = Package(url: "2", platformCompatibility: [.macos])
        try [p1, p2].save(on: app.db).wait()
        try Repository(package: p1,
                       defaultBranch: "main",
                       license: .mit,
                       name: "1",
                       owner: "foo",
                       summary: "test package").save(on: app.db).wait()
        try Repository(package: p2,
                       defaultBranch: "main",
                       license: .none,
                       name: "2",
                       owner: "bar",
                       summary: "test package").save(on: app.db).wait()
        try Version(package: p1, packageName: "p1", reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: p2, packageName: "p2", reference: .branch("main"))
            .save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()

        // MUT
        let res = try Search.fetch(app.db, ["test", "license:>mit"], page: 1, pageSize: 20).wait()

        // validate
        XCTAssertEqual(res.results.compactMap(\.packageResult?.repositoryName), [])
    }

}


extension Search.Result {
    var package: Search.PackageResult? {
        switch self {
            case .author, .keyword:
                return nil
            case .package(let result):
                return result
        }
    }

    var testDescription: String {
        switch self {
            case .author(let res):
                return "a:\(res.name)"
            case .keyword(let res):
                return "k:\(res.keyword)"
            case .package(let res):
                return "p:\(res.packageName ?? "nil")"
        }
    }
}
