// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
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

import Foundation

@testable import App

import SQLKit
import SnapshotTesting
import Testing


extension AllTests.SearchTests {

    @Test func DBRecord_packageURL() async throws {
        #expect(Search.DBRecord(matchType: .package,
                                       packageId: UUID(),
                                       repositoryName: "bar",
                                       repositoryOwner: "foo",
                                       hasDocs: false).packageURL == "/foo/bar")
        #expect(Search.DBRecord(matchType: .package,
                                       packageId: UUID(),
                                       repositoryName: "foo bar",
                                       repositoryOwner: "baz",
                                       hasDocs: false).packageURL == "/baz/foo%20bar")
    }

    @Test func packageMatchQuery_single_term() async throws {
        try await withApp { app in
            let b = Search.packageMatchQueryBuilder(on: app.db, terms: ["a"], filters: [])
            #expect(app.db.renderSQL(b) == #"SELECT 'package' AS "match_type", NULL AS "keyword", "package_id", "package_name", "repo_name", "repo_owner", "score", "summary", "stars", "license", "last_commit_date", "last_activity_at", "keywords", "has_docs", NULL::INT AS "levenshtein_dist", ts_rank("tsvector", "tsquery") >= 0.05 AS "has_exact_word_matches" FROM "search", plainto_tsquery($1) AS "tsquery" WHERE CONCAT_WS(' ', "package_name", COALESCE("summary", ''), "repo_name", "repo_owner", ARRAY_TO_STRING("keywords", ' '), ARRAY_TO_STRING("product_names", ' ')) ~* $2 AND "repo_owner" IS NOT NULL AND "repo_name" IS NOT NULL ORDER BY LOWER(COALESCE("package_name", '')) = $3 DESC, "has_exact_word_matches" DESC, "score" DESC, "stars" DESC, "package_name" ASC"#)
            #expect(app.db.binds(b) == ["a", "a", "a"])
        }
    }

    @Test func packageMatchQuery_multiple_terms() async throws {
        try await withApp { app in
            let b = Search.packageMatchQueryBuilder(on: app.db, terms: ["a", "b"], filters: [])
            #expect(app.db.renderSQL(b) == #"SELECT 'package' AS "match_type", NULL AS "keyword", "package_id", "package_name", "repo_name", "repo_owner", "score", "summary", "stars", "license", "last_commit_date", "last_activity_at", "keywords", "has_docs", NULL::INT AS "levenshtein_dist", ts_rank("tsvector", "tsquery") >= 0.05 AS "has_exact_word_matches" FROM "search", plainto_tsquery($1) AS "tsquery" WHERE CONCAT_WS(' ', "package_name", COALESCE("summary", ''), "repo_name", "repo_owner", ARRAY_TO_STRING("keywords", ' '), ARRAY_TO_STRING("product_names", ' ')) ~* $2 AND CONCAT_WS(' ', "package_name", COALESCE("summary", ''), "repo_name", "repo_owner", ARRAY_TO_STRING("keywords", ' '), ARRAY_TO_STRING("product_names", ' ')) ~* $3 AND "repo_owner" IS NOT NULL AND "repo_name" IS NOT NULL ORDER BY LOWER(COALESCE("package_name", '')) = $4 DESC, "has_exact_word_matches" DESC, "score" DESC, "stars" DESC, "package_name" ASC"#)
            #expect(app.db.binds(b) == ["a b", "a", "b", "a b"])
        }
    }

    @Test func packageMatchQuery_AuthorSearchFilter() async throws {
        try await withApp { app in
            let b = Search.packageMatchQueryBuilder(
                on: app.db, terms: ["a"],
                filters: [try AuthorSearchFilter(expression: .init(operator: .is, value: "foo"))]
            )

            #expect(app.db.renderSQL(b) == """
              SELECT 'package' AS "match_type", NULL AS "keyword", "package_id", "package_name", "repo_name", "repo_owner", "score", "summary", "stars", "license", "last_commit_date", "last_activity_at", "keywords", "has_docs", NULL::INT AS "levenshtein_dist", ts_rank("tsvector", "tsquery") >= 0.05 AS "has_exact_word_matches" FROM "search", plainto_tsquery($1) AS "tsquery" WHERE CONCAT_WS(' ', "package_name", COALESCE("summary", ''), "repo_name", "repo_owner", ARRAY_TO_STRING("keywords", ' '), ARRAY_TO_STRING("product_names", ' ')) ~* $2 AND "repo_owner" IS NOT NULL AND "repo_name" IS NOT NULL AND ("repo_owner" ILIKE $3) ORDER BY LOWER(COALESCE("package_name", '')) = $4 DESC, "has_exact_word_matches" DESC, "score" DESC, "stars" DESC, "package_name" ASC
              """)
            #expect(app.db.binds(b) == ["a", "a", "foo", "a"])
        }
    }

    @Test func packageMatchQuery_KeywordSearchFilter() async throws {
        try await withApp { app in
            let b = Search.packageMatchQueryBuilder(
                on: app.db, terms: ["a"],
                filters: [try KeywordSearchFilter(expression: .init(operator: .is,
                                                                    value: "foo"))]
            )

            #expect(app.db.renderSQL(b) == """
                SELECT 'package' AS "match_type", NULL AS "keyword", "package_id", "package_name", "repo_name", "repo_owner", "score", "summary", "stars", "license", "last_commit_date", "last_activity_at", "keywords", "has_docs", NULL::INT AS "levenshtein_dist", ts_rank("tsvector", "tsquery") >= 0.05 AS "has_exact_word_matches" FROM "search", plainto_tsquery($1) AS "tsquery" WHERE CONCAT_WS(' ', "package_name", COALESCE("summary", ''), "repo_name", "repo_owner", ARRAY_TO_STRING("keywords", ' '), ARRAY_TO_STRING("product_names", ' ')) ~* $2 AND "repo_owner" IS NOT NULL AND "repo_name" IS NOT NULL AND ($3 ILIKE ANY("keywords")) ORDER BY LOWER(COALESCE("package_name", '')) = $4 DESC, "has_exact_word_matches" DESC, "score" DESC, "stars" DESC, "package_name" ASC
                """)
            #expect(app.db.binds(b) == ["a", "a", "foo", "a"])
        }
    }

    @Test func packageMatchQuery_LastActivitySearchFilter() async throws {
        try await withApp { app in
            let b = Search.packageMatchQueryBuilder(
                on: app.db, terms: ["a"],
                filters: [try LastActivitySearchFilter(expression: .init(operator: .greaterThan,
                                                                         value: "2021-12-01"))]
            )

            #expect(app.db.renderSQL(b) == """
                SELECT 'package' AS "match_type", NULL AS "keyword", "package_id", "package_name", "repo_name", "repo_owner", "score", "summary", "stars", "license", "last_commit_date", "last_activity_at", "keywords", "has_docs", NULL::INT AS "levenshtein_dist", ts_rank("tsvector", "tsquery") >= 0.05 AS "has_exact_word_matches" FROM "search", plainto_tsquery($1) AS "tsquery" WHERE CONCAT_WS(' ', "package_name", COALESCE("summary", ''), "repo_name", "repo_owner", ARRAY_TO_STRING("keywords", ' '), ARRAY_TO_STRING("product_names", ' ')) ~* $2 AND "repo_owner" IS NOT NULL AND "repo_name" IS NOT NULL AND ("last_activity_at" > $3) ORDER BY LOWER(COALESCE("package_name", '')) = $4 DESC, "has_exact_word_matches" DESC, "score" DESC, "stars" DESC, "package_name" ASC
                """)
            #expect(app.db.binds(b) == ["a", "a", "2021-12-01", "a"])
        }
    }

    @Test func packageMatchQuery_LastCommitSearchFilter() async throws {
        try await withApp { app in
            let b = Search.packageMatchQueryBuilder(
                on: app.db, terms: ["a"],
                filters: [try LastCommitSearchFilter(expression: .init(operator: .greaterThan,
                                                                       value: "2021-12-01"))]
            )

            #expect(app.db.renderSQL(b) == """
                SELECT 'package' AS "match_type", NULL AS "keyword", "package_id", "package_name", "repo_name", "repo_owner", "score", "summary", "stars", "license", "last_commit_date", "last_activity_at", "keywords", "has_docs", NULL::INT AS "levenshtein_dist", ts_rank("tsvector", "tsquery") >= 0.05 AS "has_exact_word_matches" FROM "search", plainto_tsquery($1) AS "tsquery" WHERE CONCAT_WS(' ', "package_name", COALESCE("summary", ''), "repo_name", "repo_owner", ARRAY_TO_STRING("keywords", ' '), ARRAY_TO_STRING("product_names", ' ')) ~* $2 AND "repo_owner" IS NOT NULL AND "repo_name" IS NOT NULL AND ("last_commit_date" > $3) ORDER BY LOWER(COALESCE("package_name", '')) = $4 DESC, "has_exact_word_matches" DESC, "score" DESC, "stars" DESC, "package_name" ASC
                """)
            #expect(app.db.binds(b) == ["a", "a", "2021-12-01", "a"])
        }
    }

    @Test func packageMatchQuery_LicenseSearchFilter() async throws {
        try await withApp { app in
            let b = Search.packageMatchQueryBuilder(
                on: app.db, terms: ["a"],
                filters: [try LicenseSearchFilter(expression: .init(operator: .is, value: "mit"))]
            )

            #expect(app.db.renderSQL(b) == """
                SELECT 'package' AS "match_type", NULL AS "keyword", "package_id", "package_name", "repo_name", "repo_owner", "score", "summary", "stars", "license", "last_commit_date", "last_activity_at", "keywords", "has_docs", NULL::INT AS "levenshtein_dist", ts_rank("tsvector", "tsquery") >= 0.05 AS "has_exact_word_matches" FROM "search", plainto_tsquery($1) AS "tsquery" WHERE CONCAT_WS(' ', "package_name", COALESCE("summary", ''), "repo_name", "repo_owner", ARRAY_TO_STRING("keywords", ' '), ARRAY_TO_STRING("product_names", ' ')) ~* $2 AND "repo_owner" IS NOT NULL AND "repo_name" IS NOT NULL AND ("license" IN ($3)) ORDER BY LOWER(COALESCE("package_name", '')) = $4 DESC, "has_exact_word_matches" DESC, "score" DESC, "stars" DESC, "package_name" ASC
                """)
            #expect(app.db.binds(b) == ["a", "a", "mit", "a"])
        }
    }

    @Test func packageMatchQuery_PlatformSearchFilter() async throws {
        try await withApp { app in
            let b = Search.packageMatchQueryBuilder(
                on: app.db, terms: ["a"],
                filters: [try PlatformSearchFilter(expression: .init(operator: .is, value: "ios,macos"))]
            )

            #expect(app.db.renderSQL(b) == """
                SELECT 'package' AS "match_type", NULL AS "keyword", "package_id", "package_name", "repo_name", "repo_owner", "score", "summary", "stars", "license", "last_commit_date", "last_activity_at", "keywords", "has_docs", NULL::INT AS "levenshtein_dist", ts_rank("tsvector", "tsquery") >= 0.05 AS "has_exact_word_matches" FROM "search", plainto_tsquery($1) AS "tsquery" WHERE CONCAT_WS(' ', "package_name", COALESCE("summary", ''), "repo_name", "repo_owner", ARRAY_TO_STRING("keywords", ' '), ARRAY_TO_STRING("product_names", ' ')) ~* $2 AND "repo_owner" IS NOT NULL AND "repo_name" IS NOT NULL AND ("platform_compatibility" @> $3) ORDER BY LOWER(COALESCE("package_name", '')) = $4 DESC, "has_exact_word_matches" DESC, "score" DESC, "stars" DESC, "package_name" ASC
                """)
            #expect(app.db.binds(b) == ["a", "a", "{ios,macos}", "a"])
        }
    }

    @Test func packageMatchQuery_ProductTypeSearchFilter() async throws {
        try await withApp { app in
            for type in ProductTypeSearchFilter.ProductType.allCases {
                let b = Search.packageMatchQueryBuilder(
                    on: app.db, terms: ["a"],
                    filters: [
                        try ProductTypeSearchFilter(expression: .init(operator: .is, value: type.rawValue))
                    ]
                )
                #expect(app.db.renderSQL(b) == """
                    SELECT 'package' AS "match_type", NULL AS "keyword", "package_id", "package_name", "repo_name", "repo_owner", "score", "summary", "stars", "license", "last_commit_date", "last_activity_at", "keywords", "has_docs", NULL::INT AS "levenshtein_dist", ts_rank("tsvector", "tsquery") >= 0.05 AS "has_exact_word_matches" FROM "search", plainto_tsquery($1) AS "tsquery" WHERE CONCAT_WS(' ', "package_name", COALESCE("summary", ''), "repo_name", "repo_owner", ARRAY_TO_STRING("keywords", ' '), ARRAY_TO_STRING("product_names", ' ')) ~* $2 AND "repo_owner" IS NOT NULL AND "repo_name" IS NOT NULL AND ("product_types" @> $3) ORDER BY LOWER(COALESCE("package_name", '')) = $4 DESC, "has_exact_word_matches" DESC, "score" DESC, "stars" DESC, "package_name" ASC
                    """)
                #expect(app.db.binds(b) == ["a", "a", "{\(type.rawValue)}", "a"])
            }
        }
    }

    @Test func packageMatchQuery_StarsSearchFilter() async throws {
        try await withApp { app in
            let b = Search.packageMatchQueryBuilder(
                on: app.db, terms: ["a"],
                filters: [try StarsSearchFilter(expression: .init(operator: .greaterThan,
                                                                  value: "500"))])

            #expect(app.db.renderSQL(b) == """
                SELECT 'package' AS "match_type", NULL AS "keyword", "package_id", "package_name", "repo_name", "repo_owner", "score", "summary", "stars", "license", "last_commit_date", "last_activity_at", "keywords", "has_docs", NULL::INT AS "levenshtein_dist", ts_rank("tsvector", "tsquery") >= 0.05 AS "has_exact_word_matches" FROM "search", plainto_tsquery($1) AS "tsquery" WHERE CONCAT_WS(' ', "package_name", COALESCE("summary", ''), "repo_name", "repo_owner", ARRAY_TO_STRING("keywords", ' '), ARRAY_TO_STRING("product_names", ' ')) ~* $2 AND "repo_owner" IS NOT NULL AND "repo_name" IS NOT NULL AND ("stars" > $3) ORDER BY LOWER(COALESCE("package_name", '')) = $4 DESC, "has_exact_word_matches" DESC, "score" DESC, "stars" DESC, "package_name" ASC
                """)
            #expect(app.db.binds(b) == ["a", "a", "500", "a"])
        }
    }

    @Test func keywordMatchQuery_single_term() async throws {
        try await withApp { app in
            let b = Search.keywordMatchQueryBuilder(on: app.db, terms: ["a"])
            #expect(app.db.renderSQL(b) == #"SELECT DISTINCT 'keyword' AS "match_type", "keyword", NULL::UUID AS "package_id", NULL AS "package_name", NULL AS "repo_name", NULL AS "repo_owner", NULL::INT AS "score", NULL AS "summary", NULL::INT AS "stars", NULL AS "license", NULL::TIMESTAMP AS "last_commit_date", NULL::TIMESTAMP AS "last_activity_at", NULL::TEXT[] AS "keywords", NULL::BOOL AS "has_docs", NULL::INT AS "levenshtein_dist", NULL::BOOL AS "has_exact_word_matches" FROM "search", UNNEST("keywords") AS "keyword" WHERE "keyword" ILIKE $1 LIMIT 50"#)
            #expect(app.db.binds(b) == ["%a%"])
        }
    }

    @Test func keywordMatchQuery_multiple_terms() async throws {
        try await withApp { app in
            let b = Search.keywordMatchQueryBuilder(on: app.db, terms: ["a", "b"])
            #expect(app.db.renderSQL(b) == #"SELECT DISTINCT 'keyword' AS "match_type", "keyword", NULL::UUID AS "package_id", NULL AS "package_name", NULL AS "repo_name", NULL AS "repo_owner", NULL::INT AS "score", NULL AS "summary", NULL::INT AS "stars", NULL AS "license", NULL::TIMESTAMP AS "last_commit_date", NULL::TIMESTAMP AS "last_activity_at", NULL::TEXT[] AS "keywords", NULL::BOOL AS "has_docs", NULL::INT AS "levenshtein_dist", NULL::BOOL AS "has_exact_word_matches" FROM "search", UNNEST("keywords") AS "keyword" WHERE "keyword" ILIKE $1 LIMIT 50"#)
            #expect(app.db.binds(b) == ["%a b%"])
        }
    }

    @Test func authorMatchQuery_single_term() async throws {
        try await withApp { app in
            let b = Search.authorMatchQueryBuilder(on: app.db, terms: ["a"])
            #expect(app.db.renderSQL(b) == #"SELECT DISTINCT 'author' AS "match_type", NULL AS "keyword", NULL::UUID AS "package_id", NULL AS "package_name", NULL AS "repo_name", "repo_owner", NULL::INT AS "score", NULL AS "summary", NULL::INT AS "stars", NULL AS "license", NULL::TIMESTAMP AS "last_commit_date", NULL::TIMESTAMP AS "last_activity_at", NULL::TEXT[] AS "keywords", NULL::BOOL AS "has_docs", LEVENSHTEIN("repo_owner", $1) AS "levenshtein_dist", NULL::BOOL AS "has_exact_word_matches" FROM "search" WHERE "repo_owner" ILIKE $2 ORDER BY "levenshtein_dist" LIMIT 50"#)
            #expect(app.db.binds(b) == ["a", "%a%"])
        }
    }

    @Test func authorMatchQuery_multiple_term() async throws {
        try await withApp { app in
            let b = Search.authorMatchQueryBuilder(on: app.db, terms: ["a", "b"])
            #expect(app.db.renderSQL(b) == #"SELECT DISTINCT 'author' AS "match_type", NULL AS "keyword", NULL::UUID AS "package_id", NULL AS "package_name", NULL AS "repo_name", "repo_owner", NULL::INT AS "score", NULL AS "summary", NULL::INT AS "stars", NULL AS "license", NULL::TIMESTAMP AS "last_commit_date", NULL::TIMESTAMP AS "last_activity_at", NULL::TEXT[] AS "keywords", NULL::BOOL AS "has_docs", LEVENSHTEIN("repo_owner", $1) AS "levenshtein_dist", NULL::BOOL AS "has_exact_word_matches" FROM "search" WHERE "repo_owner" ILIKE $2 ORDER BY "levenshtein_dist" LIMIT 50"#)
            #expect(app.db.binds(b) == ["a b", "%a b%"])
        }
    }

    @Test func query_sql() async throws {
        // Test to confirm shape of rendered search SQL
        try await withApp { app in
            // MUT
            let query = try #require(Search.query(app.db, ["test"], page: 1, pageSize: 20))
            // validate
            #expect(app.db.renderSQL(query) == """
            SELECT * FROM ((SELECT DISTINCT 'author' AS "match_type", NULL AS "keyword", NULL::UUID AS "package_id", NULL AS "package_name", NULL AS "repo_name", "repo_owner", NULL::INT AS "score", NULL AS "summary", NULL::INT AS "stars", NULL AS "license", NULL::TIMESTAMP AS "last_commit_date", NULL::TIMESTAMP AS "last_activity_at", NULL::TEXT[] AS "keywords", NULL::BOOL AS "has_docs", LEVENSHTEIN("repo_owner", $1) AS "levenshtein_dist", NULL::BOOL AS "has_exact_word_matches" FROM "search" WHERE "repo_owner" ILIKE $2 ORDER BY "levenshtein_dist" LIMIT 50) UNION ALL (SELECT DISTINCT 'keyword' AS "match_type", "keyword", NULL::UUID AS "package_id", NULL AS "package_name", NULL AS "repo_name", NULL AS "repo_owner", NULL::INT AS "score", NULL AS "summary", NULL::INT AS "stars", NULL AS "license", NULL::TIMESTAMP AS "last_commit_date", NULL::TIMESTAMP AS "last_activity_at", NULL::TEXT[] AS "keywords", NULL::BOOL AS "has_docs", NULL::INT AS "levenshtein_dist", NULL::BOOL AS "has_exact_word_matches" FROM "search", UNNEST("keywords") AS "keyword" WHERE "keyword" ILIKE $3 LIMIT 50) UNION ALL (SELECT 'package' AS "match_type", NULL AS "keyword", "package_id", "package_name", "repo_name", "repo_owner", "score", "summary", "stars", "license", "last_commit_date", "last_activity_at", "keywords", "has_docs", NULL::INT AS "levenshtein_dist", ts_rank("tsvector", "tsquery") >= 0.05 AS "has_exact_word_matches" FROM "search", plainto_tsquery($4) AS "tsquery" WHERE CONCAT_WS(' ', "package_name", COALESCE("summary", ''), "repo_name", "repo_owner", ARRAY_TO_STRING("keywords", ' '), ARRAY_TO_STRING("product_names", ' ')) ~* $5 AND "repo_owner" IS NOT NULL AND "repo_name" IS NOT NULL ORDER BY LOWER(COALESCE("package_name", '')) = $6 DESC, "has_exact_word_matches" DESC, "score" DESC, "stars" DESC, "package_name" ASC LIMIT 21 OFFSET 0)) AS "t"
            """)
            #expect(app.db.binds(query) == ["test", "%test%", "%test%", "test", "test", "test"])
        }
    }

    @Test func fetch_single() async throws {
        // Test search with a single term
        try await withApp { app in
            // setup
            let p1 = try await savePackage(on: app.db, id: .id1, "1")
            let p2 = try await savePackage(on: app.db, id: .id2, "2")
            try await Repository(package: p1,
                                 defaultBranch: "main",
                                 summary: "some package").save(on: app.db)
            try await Repository(package: p2,
                                 defaultBranch: "main",
                                 lastCommitDate: .t0,
                                 name: "name 2",
                                 owner: "owner 2",
                                 stars: 1234,
                                 summary: "bar package").save(on: app.db)
            try await Version(package: p1, packageName: "Foo", reference: .branch("main")).save(on: app.db)
            try await Version(package: p2, packageName: "Bar", reference: .branch("main")).save(on: app.db)
            try await Search.refresh(on: app.db)

            // MUT
            let res = try await Search.fetch(app.db, ["bar"], page: 1, pageSize: 20)

            // validation
            #expect(res == .init(hasMoreResults: false,
                                 searchTerm: "bar",
                                 searchFilters: [],
                                 results: [
                                    .package(
                                        .init(packageId: .id2,
                                              packageName: "Bar",
                                              packageURL: "/owner%202/name%202",
                                              repositoryName: "name 2",
                                              repositoryOwner: "owner 2",
                                              stars: 1234,
                                              lastActivityAt: .t0,
                                              summary: "bar package",
                                              keywords: [],
                                              hasDocs: false)!
                                    )
                                 ])
            )
        }
    }

    @Test func fetch_multiple() async throws {
        // Test search with multiple terms ("and")
        try await withApp { app in
            // setup
            let p1 = try await savePackage(on: app.db, id: .id1, "1")
            let p2 = try await savePackage(on: app.db, id: .id2, "2")
            try await Repository(package: p1,
                                 defaultBranch: "main",
                                 name: "package 1",
                                 owner: "owner",
                                 summary: "package 1 description").save(on: app.db)
            try await Repository(package: p2,
                                 defaultBranch: "main",
                                 lastCommitDate: .t0,
                                 name: "package 2",
                                 owner: "owner",
                                 stars: 1234,
                                 summary: "package 2 description").save(on: app.db)
            try await Version(package: p1, packageName: "Foo", reference: .branch("main")).save(on: app.db)
            try await Version(package: p2, packageName: "Bar", reference: .branch("main")).save(on: app.db)
            try await Search.refresh(on: app.db)

            // MUT
            let res = try await Search.fetch(app.db, ["owner", "bar"], page: 1, pageSize: 20)

            // validation
            #expect(res == .init(hasMoreResults: false,
                                 searchTerm: "owner bar",
                                 searchFilters: [],
                                 results: [
                                    .package(
                                        .init(packageId: .id2,
                                              packageName: "Bar",
                                              packageURL: "/owner/package%202",
                                              repositoryName: "package 2",
                                              repositoryOwner: "owner",
                                              stars: 1234,
                                              lastActivityAt: .t0,
                                              summary: "package 2 description",
                                              keywords: [],
                                              hasDocs: false)!
                                    )
                                 ])
            )
        }
    }

    @Test func fetch_distinct() async throws {
        // Ensure we de-duplicate results
        try await withApp { app in
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
            try await Search.refresh(on: app.db)

            // MUT
            let res = try await Search.fetch(app.db, ["bar"], page: 1, pageSize: 20)

            // validate
            #expect(res.results.count == 1)
            #expect(res.results.compactMap(\.packageResult?.repositoryName) == ["bar"])
        }
    }

    @Test func quoting() async throws {
        // Test searching for a `'`
        try await withApp { app in
            // setup
            let p1 = try await savePackage(on: app.db, id: .id1, "1")
            let p2 = try await savePackage(on: app.db, id: .id2, "2")
            try await Repository(package: p1,
                                 defaultBranch: "main",
                                 lastCommitDate: .t0,
                                 name: "name 1",
                                 owner: "owner 1",
                                 stars: 1234,
                                 summary: "some 'package'").save(on: app.db)
            try await Repository(package: p2,
                                 defaultBranch: "main",
                                 lastCommitDate: .t0,
                                 name: "name 2",
                                 owner: "owner 2",
                                 summary: "bar package").save(on: app.db)
            try await Version(package: p1, packageName: "Foo", reference: .branch("main")).save(on: app.db)
            try await Version(package: p2, packageName: "Bar", reference: .branch("main")).save(on: app.db)
            try await Search.refresh(on: app.db)

            // MUT
            let res = try await Search.fetch(app.db, ["'"], page: 1, pageSize: 20)

            // validation
            #expect(res == .init(hasMoreResults: false,
                                 searchTerm: "'",
                                 searchFilters: [],
                                 results: [
                                    .package(
                                        .init(packageId: .id1,
                                              packageName: "Foo",
                                              packageURL: "/owner%201/name%201",
                                              repositoryName: "name 1",
                                              repositoryOwner: "owner 1",
                                              stars: 1234,
                                              lastActivityAt: .t0,
                                              summary: "some 'package'",
                                              keywords: [],
                                              hasDocs: false)!
                                    )
                                 ])
            )
        }
    }

    @Test func search_pagination() async throws {
        // setup
        try await withApp { app in
            let packages = (0..<9).map { idx in
                Package(url: "\(idx)".url, score: 15 - idx)
            }
            try await packages.save(on: app.db)
            try await packages.map { try Repository(package: $0, defaultBranch: "default",
                                                    name: $0.url, owner: "foobar") }
            .save(on: app.db)
            try await packages.map { try Version(package: $0, packageName: $0.url, reference: .branch("default")) }
                .save(on: app.db)
            try await Search.refresh(on: app.db)

            do {  // first page
                  // MUT
                let res = try await API.search(database: app.db,
                                               query: .init(query: "foo", page: 1, pageSize: 3))

                // validate
                #expect(res.hasMoreResults)
                #expect(res.results.map(\.testDescription) == ["a:foobar", "p:0", "p:1", "p:2"])
            }

            do {  // second page
                  // MUT
                let res = try await API.search(database: app.db,
                                               query: .init(query: "foo", page: 2, pageSize: 3))

                // validate
                #expect(res.hasMoreResults)
                #expect(res.results.map(\.testDescription) == ["p:3", "p:4", "p:5"])
            }

            do {  // third page
                  // MUT
                let res = try await API.search(database: app.db,
                                               query: .init(query: "foo", page: 3, pageSize: 3))

                // validate
                #expect(!res.hasMoreResults)
                #expect(res.results.map(\.testDescription) == ["p:6", "p:7", "p:8"])
            }
        }
    }

    @Test func search_pagination_with_author_keyword_results() async throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1198
        try await withApp { app in
            // setup
            let packages = (0..<9).map { idx in
                Package(url: "\(idx)".url, score: 15 - idx)
            }
            try await packages.save(on: app.db)
            try await packages.map { try Repository(package: $0,
                                                    defaultBranch: "default",
                                                    keywords: ["foo"],
                                                    name: $0.url,
                                                    owner: "foobar") }
            .save(on: app.db)
            try await packages.map { try Version(package: $0, packageName: $0.url, reference: .branch("default")) }
                .save(on: app.db)
            try await Search.refresh(on: app.db)

            do {  // first page
                  // MUT
                let res = try await API.search(database: app.db,
                                               query: .init(query: "foo", page: 1, pageSize: 3))

                // validate
                #expect(res.hasMoreResults)
                #expect(res.results.map(\.testDescription) == ["a:foobar", "k:foo", "p:0", "p:1", "p:2"])
            }

            do {  // second page
                  // MUT
                let res = try await API.search(database: app.db,
                                               query: .init(query: "foo", page: 2, pageSize: 3))

                // validate
                #expect(res.hasMoreResults)
                #expect(res.results.map(\.testDescription) == ["p:3", "p:4", "p:5"])
            }
        }
    }

    @Test func search_pagination_invalid_input() async throws {
        // Test invalid pagination inputs
        try await withApp { app in
            // setup
            let packages = (0..<9).map { idx in
                Package(url: "\(idx)".url, score: 15 - idx)
            }
            try await packages.save(on: app.db)
            try await packages.map { try Repository(package: $0, defaultBranch: "default",
                                                    name: $0.url, owner: "foobar") }
            .save(on: app.db)

            try await packages.map { try Version(package: $0, packageName: $0.url, reference: .branch("default")) }
                .save(on: app.db)

            try await Search.refresh(on: app.db)

            do {  // page out of bounds (too large)
                  // MUT
                let res = try await API.search(database: app.db,
                                               query: .init(query: "foo", page: 4, pageSize: 3))

                // validate
                #expect(!res.hasMoreResults)
                #expect(res.results.map(\.package?.repositoryName) == [])
            }

            do {  // page out of bounds (too small - will be clamped to page 1)
                  // MUT
                let res = try await API.search(database: app.db,
                                               query: .init(query: "foo", page: 0, pageSize: 3))
                #expect(res.hasMoreResults)
                #expect(res.results.map(\.testDescription) == ["a:foobar", "p:0", "p:1", "p:2"])
            }
        }
    }

    @Test func order_by_score() async throws {
        try await withApp { app in
            // setup
            for idx in (0..<10).shuffled() {
                let p = Package(id: UUID(), url: "\(idx)".url, score: idx)
                try await p.save(on: app.db)
                try await Repository(package: p,
                                     defaultBranch: "main",
                                     name: "\(idx)",
                                     owner: "foobar",
                                     summary: "\(idx)").save(on: app.db)
                try await Version(package: p, packageName: "\(idx)", reference: .branch("main")).save(on: app.db)
            }
            try await Search.refresh(on: app.db)

            // MUT
            let res = try await Search.fetch(app.db, ["foo"], page: 1, pageSize: 20)

            // validation
            #expect(res.results.count == 11)
            #expect(res.results.map(\.testDescription) == ["a:foobar", "p:9", "p:8", "p:7", "p:6", "p:5", "p:4", "p:3", "p:2", "p:1", "p:0"])
        }
    }

    @Test func exact_name_match() async throws {
        // Ensure exact name matches are boosted
        try await withApp { app in
            // setup
            // We have three packages that all match in some way:
            // 1: exact package name match - we want this one to be at the top
            // 2: package name contains search term
            // 3: summary contains search term
            let p1 = Package(id: UUID(), url: "1", score: 10)
            let p2 = Package(id: UUID(), url: "2", score: 20)
            let p3 = Package(id: UUID(), url: "3", score: 30)
            try await [p1, p2, p3].save(on: app.db)
            try await Repository(package: p1,
                                 defaultBranch: "main",
                                 name: "1",
                                 owner: "foo",
                                 summary: "").save(on: app.db)
            try await Repository(package: p2,
                                 defaultBranch: "main",
                                 name: "2",
                                 owner: "foo",
                                 summary: "").save(on: app.db)
            try await Repository(package: p3,
                                 defaultBranch: "main",
                                 name: "3",
                                 owner: "foo",
                                 summary: "link").save(on: app.db)
            try await Version(package: p1, packageName: "Ink", reference: .branch("main"))
                .save(on: app.db)
            try await Version(package: p2, packageName: "inkInName", reference: .branch("main"))
                .save(on: app.db)
            try await Version(package: p3, packageName: "some name", reference: .branch("main"))
                .save(on: app.db)
            try await Search.refresh(on: app.db)

            // MUT
            let res = try await Search.fetch(app.db, ["ink"], page: 1, pageSize: 20)

            #expect(res.results.map(\.package?.repositoryName) == ["1", "3", "2"])
        }
    }

    @Test func exact_name_match_whitespace() async throws {
        // Ensure exact name matches are boosted, for package name with whitespace
        try await withApp { app in
            // setup
            // We have three packages that all match in some way:
            // 1: exact package name match - we want this one to be at the top
            // 2: package name contains search term
            // 3: summary contains search term
            let p1 = Package(id: UUID(), url: "1", score: 10)
            let p2 = Package(id: UUID(), url: "2", score: 20)
            let p3 = Package(id: UUID(), url: "3", score: 30)
            try await [p1, p2, p3].save(on: app.db)
            try await Repository(package: p1,
                                 defaultBranch: "main",
                                 name: "1",
                                 owner: "foo",
                                 summary: "").save(on: app.db)
            try await Repository(package: p2,
                                 defaultBranch: "main",
                                 name: "2",
                                 owner: "foo",
                                 summary: "").save(on: app.db)
            try await Repository(package: p3,
                                 defaultBranch: "main",
                                 name: "3",
                                 owner: "foo",
                                 summary: "foo bar").save(on: app.db)
            try await Version(package: p1, packageName: "Foo bar", reference: .branch("main"))
                .save(on: app.db)
            try await Version(package: p2, packageName: "foobar", reference: .branch("main"))
                .save(on: app.db)
            try await Version(package: p3, packageName: "some name", reference: .branch("main"))
                .save(on: app.db)
            try await Search.refresh(on: app.db)

            // MUT
            let res = try await Search.fetch(app.db, ["foo", "bar"], page: 1, pageSize: 20)

            #expect(res.results.map(\.package?.repositoryName) == ["1", "3", "2"])
        }
    }

    @Test func exact_name_null_packageName() async throws {
        // Ensure null packageName value aren't boosted
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2072
        try await withApp { app in
            // setup
            // We have three packages that match the search term "bar" via their summary.
            // The third package has no package name. This test ensure it's not boosted
            // to the front.
            let p1 = Package(id: UUID(), url: "1", score: 30)
            let p2 = Package(id: UUID(), url: "2", score: 20)
            let p3 = Package(id: UUID(), url: "3", score: 10)
            try await [p1, p2, p3].save(on: app.db)
            try await Repository(package: p1,
                                 defaultBranch: "main",
                                 name: "1",
                                 owner: "foo",
                                 summary: "bar1").save(on: app.db)
            try await Repository(package: p2,
                                 defaultBranch: "main",
                                 name: "2",
                                 owner: "foo",
                                 summary: "bar2").save(on: app.db)
            try await Repository(package: p3,
                                 defaultBranch: "main",
                                 name: "3",
                                 owner: "foo",
                                 summary: "bar3").save(on: app.db)
            try await Version(package: p1, packageName: "Bar1", reference: .branch("main"))
                .save(on: app.db)
            try await Version(package: p2, packageName: "Bar2", reference: .branch("main"))
                .save(on: app.db)
            try await Version(package: p3, packageName: nil, reference: .branch("main"))
                .save(on: app.db)
            try await Search.refresh(on: app.db)

            // MUT
            let res = try await Search.fetch(app.db, ["bar"], page: 1, pageSize: 20)

            #expect(res.results.map(\.package?.repositoryName) == ["1", "2", "3"])
        }
    }

    @Test func exclude_null_fields() async throws {
        // Ensure excluding results with NULL fields
        try await withApp { app in
            // setup:
            // Packages that all match but each having one NULL for a required field
            let p1 = Package(id: UUID(), url: "1", score: 10)
            let p2 = Package(id: UUID(), url: "2", score: 20)
            try await [p1, p2].save(on: app.db)
            try await Repository(package: p1,
                                 defaultBranch: "main",
                                 name: nil, // Missing repository name
                                 owner: "foobar",
                                 summary: "").save(on: app.db)
            try await Repository(package: p2,
                                 defaultBranch: "main",
                                 name: "2",
                                 owner: nil, // Missing repository owner
                                 summary: "foo bar").save(on: app.db)
            try await Version(package: p1, packageName: "foo1", reference: .branch("main"))
                .save(on: app.db)
            try await Version(package: p2, packageName: "foo2", reference: .branch("main"))
                .save(on: app.db)
            try await Search.refresh(on: app.db)

            // MUT
            let res = try await Search.fetch(app.db, ["foo"], page: 1, pageSize: 20)

            // ensure only the author result is coming through, not the packages
            #expect(res.results.map(\.testDescription) == ["a:foobar"])
        }
    }

    @Test func include_null_package_name() async throws {
        // Ensure that packages that somehow have a NULL package name do *not* get excluded from search results.
        try await withApp { app in
            let p1 = Package(id: .id0, url: "1", score: 10)
            try await p1.save(on: app.db)

            try await Repository(package: p1,
                                 defaultBranch: "main",
                                 name: "1",
                                 owner: "bar",
                                 summary: "foo and bar").save(on: app.db)

            // Version record with a missing package name.
            try await Version(package: p1, packageName: nil, reference: .branch("main"))
                .save(on: app.db)

            try await Search.refresh(on: app.db)

            // MUT
            let res = try await Search.fetch(app.db, ["foo"], page: 1, pageSize: 20)

            let packageResult = try #require(res.results.first?.package)
            #expect(packageResult.packageId == .id0)
            #expect(packageResult.repositoryName == "1")
            #expect(packageResult.repositoryOwner == "bar")
            #expect(packageResult.packageName == nil)
        }
    }

    @Test func exact_word_match() async throws {
        // Ensure exact word matches are boosted
        // See also https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2072
        try await withApp { app in
            // setup
            // We have three packages that all match the search term "ping". This test
            // ensures the one with the whole word match is boosted to the front
            // despite having the lowest score.
            let p1 = Package(id: UUID(), url: "1", score: 30)
            let p2 = Package(id: UUID(), url: "2", score: 20)
            let p3 = Package(id: UUID(), url: "3", score: 10)
            try await [p1, p2, p3].save(on: app.db)
            try await Repository(package: p1,
                                 defaultBranch: "main",
                                 name: "1",
                                 owner: "foo",
                                 summary: "mapping").save(on: app.db)
            try await Repository(package: p2,
                                 defaultBranch: "main",
                                 name: "2",
                                 owner: "foo",
                                 summary: "flopping").save(on: app.db)
            try await Repository(package: p3,
                                 defaultBranch: "main",
                                 name: "3",
                                 owner: "foo",
                                 summary: "ping").save(on: app.db)
            try await Version(package: p1, packageName: "Foo1", reference: .branch("main"))
                .save(on: app.db)
            try await Version(package: p2, packageName: "Foo2", reference: .branch("main"))
                .save(on: app.db)
            try await Version(package: p3, packageName: "Foo3", reference: .branch("main"))
                .save(on: app.db)
            try await Search.refresh(on: app.db)

            // MUT
            let res = try await Search.fetch(app.db, ["ping"], page: 1, pageSize: 20)

            // validate
            #expect(res.results.map(\.package?.repositoryName) == ["3", "1", "2"])
        }
    }

    @Test func repo_word_match() async throws {
        // Ensure the repository name is part of word matching
        // See also https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2263
        // We have two packages that both match the search term "syntax". This test
        // ensures the one where the match is only in the repository name gets still
        // ranked first due to its higher score.
        try await withApp { app in
            let p1 = Package(id: UUID(), url: "foo/bar", score: 10)
            let p2 = Package(id: UUID(), url: "foo/swift-syntax", score: 20)
            try await [p1, p2].save(on: app.db)
            try await Repository(package: p1,
                                 defaultBranch: "main",
                                 name: "bar",
                                 owner: "foo",
                                 summary: "syntax").save(on: app.db)
            try await Repository(package: p2,
                                 defaultBranch: "main",
                                 name: "swift-syntax",
                                 owner: "foo").save(on: app.db)
            try await Version(package: p1, packageName: "Bar", reference: .branch("main"))
                .save(on: app.db)
            try await Version(package: p2, packageName: "SwiftSyntax", reference: .branch("main"))
                .save(on: app.db)
            try await Search.refresh(on: app.db)

            // MUT
            let res = try await Search.fetch(app.db, ["syntax"], page: 1, pageSize: 20)

            // validate
            #expect(res.results.map(\.package?.repositoryName) == ["swift-syntax", "bar"])
        }
    }

    @Test func sanitize() async throws {
        #expect(Search.sanitize(["*"]) == ["\\*"])
        #expect(Search.sanitize(["?"]) == ["\\?"])
        #expect(Search.sanitize(["("]) == ["\\("])
        #expect(Search.sanitize([")"]) == ["\\)"])
        #expect(Search.sanitize(["["]) == ["\\["])
        #expect(Search.sanitize(["]"]) == ["\\]"])
        #expect(Search.sanitize(["\\"]) == [])
        #expect(Search.sanitize(["test\\"]) == ["test"])
    }

    @Test func invalid_characters() async throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/974
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1402
        // Ensure we don't raise a 500 for certain characters
        // "server: invalid regular expression: quantifier operand invalid"
        try await withApp { app in
            do {
                // MUT
                let res = try await Search.fetch(app.db, ["*"], page: 1, pageSize: 20)

                // validation
                #expect(res == .init(hasMoreResults: false, searchTerm: "\\*", searchFilters: [], results: []))
            }

            do {
                // MUT
                let res = try await Search.fetch(app.db, ["\\"], page: 1, pageSize: 20)

                // validation
                #expect(res == .init(hasMoreResults: false, searchTerm: "", searchFilters: [], results: []))
            }
        }
    }

    @Test func search_keyword() async throws {
        // Test searching for a keyword
        // setup
        // p1: decoy
        // p2: match
        try await withApp { app in
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
            try await Search.refresh(on: app.db)

            // MUT
            let res = try await Search.fetch(app.db, ["topic"], page: 1, pageSize: 20)

            #expect(res.results.map(\.testDescription) == ["k:topic", "p:p1"])
        }
    }

    @Test func search_keyword_multiple_results() async throws {
        // Test searching with multiple keyword results
        // setup
        // p1: decoy
        // p2: match
        try await withApp { app in
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
            try await Search.refresh(on: app.db)

            // MUT
            let res = try await Search.fetch(app.db, ["topic"], page: 1, pageSize: 20)

            // validate
            // The keyword results are unordered in SQL because they're ordered by frequency
            // after fetching. We sort them here for stable test results.
            // (packages are also matched via their keywords)
            #expect(res.results.map(\.testDescription).sorted() == ["k:atopicb", "k:topic", "k:topicb", "p:p1", "p:p2", "p:p3"])
        }
    }

    @Test func search_author_multiple_results() async throws {
        // Test searching with multiple authors results
        // setup
        // p1: decoy
        // p2: match
        try await withApp { app in
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
            try await Search.refresh(on: app.db)

            // MUT
            let res = try await Search.fetch(app.db, ["author"], page: 1, pageSize: 20)

            // validate that keyword results are ordered by levenshtein distance
            // (packages are also matched via their keywords)
            #expect(res.results.map(\.testDescription) == ["a:author", "a:author-2", "a:another-author", "p:p3", "p:p2", "p:p1"])
        }
    }

    @Test func search_author() async throws {
        // Test searching for an author
        // setup
        // p1: decoy
        // p2: match
        try await withApp { app in
            let p1 = Package(id: .id1, url: "1", score: 10)
            let p2 = Package(id: .id2, url: "2", score: 20)
            try await [p1, p2].save(on: app.db)
            try await Repository(package: p1,
                                 defaultBranch: "main",
                                 name: "1",
                                 owner: "bar",
                                 summary: "").save(on: app.db)
            try await Repository(package: p2,
                                 defaultBranch: "main",
                                 lastCommitDate: .t0,
                                 name: "2",
                                 owner: "foo",
                                 stars: 1234,
                                 summary: "").save(on: app.db)
            try await Version(package: p1, packageName: "p1", reference: .branch("main"))
                .save(on: app.db)
            try await Version(package: p2, packageName: "p2", reference: .branch("main"))
                .save(on: app.db)
            try await Search.refresh(on: app.db)

            // MUT
            let res = try await Search.fetch(app.db, ["foo"], page: 1, pageSize: 20)

            #expect(res.results == [
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
                               keywords: [],
                               hasDocs: false)!)
            ])
        }
    }

    @Test func search_module_name() async throws {
        // Test searching for a term that only appears in a module (target) name
        // setup
        // p1: decoy
        // p2: match
        try await withApp { app in
            let p1 = Package(id: .id1, url: "1", score: 10)
            let p2 = Package(id: .id2, url: "2", score: 20)
            try await [p1, p2].save(on: app.db)
            try await Repository(package: p1, defaultBranch: "main", name: "1", owner: "foo").save(on: app.db)
            try await Repository(package: p2, defaultBranch: "main", name: "2", owner: "foo").save(on: app.db)
            try await Version(package: p1, packageName: "p1", reference: .branch("main"))
                .save(on: app.db)
            let v2 = try Version(package: p2, latest: .defaultBranch, packageName: "p2", reference: .branch("main"))
            try await v2.save(on: app.db)
            try await Product(version: v2, type: .library(.automatic), name: "ModuleName").save(on: app.db)
            try await Search.refresh(on: app.db)

            // MUT
            let res = try await Search.fetch(app.db, ["modulename"], page: 1, pageSize: 20)

            #expect(res.results.count == 1)
            #expect(res.results == [
                .package(.init(packageId: .id2,
                               packageName: "p2",
                               packageURL: "/foo/2",
                               repositoryName: "2",
                               repositoryOwner: "foo",
                               stars: 0,
                               lastActivityAt: nil,
                               summary: nil,
                               keywords: [],
                               hasDocs: false)!)
            ])
        }
    }

    @Test func search_withoutTerms() async throws {
        try await withApp { app in
            // Setup
            let p1 = Package(id: .id1, url: "1", score: 10)
            let p2 = Package(id: .id2, url: "2", score: 20)
            try await [p1, p2].save(on: app.db)
            try await Repository(package: p1,
                                 defaultBranch: "main",
                                 keywords: ["a"],
                                 name: "1",
                                 owner: "bar",
                                 stars: 50,
                                 summary: "test package").save(on: app.db)
            try await Repository(package: p2,
                                 defaultBranch: "main",
                                 keywords: ["b"],
                                 name: "2",
                                 owner: "foo",
                                 stars: 10,
                                 summary: "test package").save(on: app.db)
            try await Version(package: p1, packageName: "p1", reference: .branch("main"))
                .save(on: app.db)
            try await Version(package: p2, packageName: "p2", reference: .branch("main"))
                .save(on: app.db)
            try await Search.refresh(on: app.db)

            // MUT
            let res = try await Search.fetch(app.db, ["stars:>15"], page: 1, pageSize: 20)
            #expect(res.results.count == 1)
            #expect(res.results.compactMap(\.package).compactMap(\.packageName).sorted() == ["p1"])
        }
    }

    @Test func search_withFilter_stars() async throws {
        try await withApp { app in
            // Setup
            let p1 = Package(id: .id1, url: "1", score: 10)
            let p2 = Package(id: .id2, url: "2", score: 20)
            try await [p1, p2].save(on: app.db)
            try await Repository(package: p1,
                                 defaultBranch: "main",
                                 name: "1",
                                 owner: "bar",
                                 stars: 50,
                                 summary: "test package").save(on: app.db)
            try await Repository(package: p2,
                                 defaultBranch: "main",
                                 name: "2",
                                 owner: "foo",
                                 stars: 10,
                                 summary: "test package").save(on: app.db)
            try await Version(package: p1, packageName: "p1", reference: .branch("main"))
                .save(on: app.db)
            try await Version(package: p2, packageName: "p2", reference: .branch("main"))
                .save(on: app.db)
            try await Search.refresh(on: app.db)

            do { // Baseline
                let res = try await Search.fetch(app.db, ["test"], page: 1, pageSize: 20)
                #expect(res.results.count == 2)
                #expect(res.results.compactMap(\.package).compactMap(\.packageName).sorted() == ["p1", "p2"])
            }

            do { // Greater Than
                let res = try await Search.fetch(app.db, ["test", "stars:>25"], page: 1, pageSize: 20)
                #expect(res.results.count == 1)
                #expect(res.results.first?.package?.packageName == "p1")
            }

            do { // Less Than
                let res = try await Search.fetch(app.db, ["test", "stars:<25"], page: 1, pageSize: 20)
                #expect(res.results.count == 1)
                #expect(res.results.first?.package?.packageName == "p2")
            }

            do { // Equal
                let res = try await Search.fetch(app.db, ["test", "stars:50"], page: 1, pageSize: 20)
                #expect(res.results.count == 1)
                #expect(res.results.first?.package?.packageName == "p1")
            }

            do { // Not Equals
                let res = try await Search.fetch(app.db, ["test", "stars:!50"], page: 1, pageSize: 20)
                #expect(res.results.count == 1)
                #expect(res.results.first?.package?.packageName == "p2")
            }
        }
    }

    @Test func onlyPackageResults_whenFiltersApplied() async throws {
        try await withApp { app in
            do { // with filter
                let query = try #require(Search.query(app.db, ["a", "stars:500"], page: 1, pageSize: 5))
                let sql = app.db.renderSQL(query)
                #expect(sql.contains(#"SELECT DISTINCT 'author' AS "match_type""#))
                #expect(sql.contains(#"SELECT DISTINCT 'keyword' AS "match_type""#))
                #expect(sql.contains(#"SELECT 'package' AS "match_type""#))
            }

            do { // without filter
                let query = try #require(Search.query(app.db, ["a"], page: 1, pageSize: 5))
                let sql = app.db.renderSQL(query)
                #expect(sql.contains(#"SELECT DISTINCT 'author' AS "match_type""#))
                #expect(sql.contains(#"SELECT DISTINCT 'keyword' AS "match_type""#))
                #expect(sql.contains(#"SELECT 'package' AS "match_type""#))
            }
        }
    }

    @Test func authorSearchFilter() async throws {
        try await withApp { app in
            // Setup
            let p1 = Package(url: "1", platformCompatibility: [.iOS])
            let p2 = Package(url: "2", platformCompatibility: [.macOS])
            try await [p1, p2].save(on: app.db)
            try await Repository(package: p1,
                                 defaultBranch: "main",
                                 name: "1",
                                 owner: "foo",
                                 summary: "test package").save(on: app.db)
            try await Repository(package: p2,
                                 defaultBranch: "main",
                                 name: "2",
                                 owner: "bar",
                                 summary: "test package").save(on: app.db)
            try await Version(package: p1, packageName: "p1", reference: .branch("main"))
                .save(on: app.db)
            try await Version(package: p2, packageName: "p2", reference: .branch("main"))
                .save(on: app.db)
            try await Search.refresh(on: app.db)

            do {
                // MUT
                let res = try await Search.fetch(app.db, ["test", "author:foo"], page: 1, pageSize: 20)

                // validate
                #expect(res.results.compactMap(\.packageResult?.repositoryName) == ["1"])
            }

            do {  // double check that leaving the filter term off selects both packages
                  // MUT
                let res = try await Search.fetch(app.db, ["test"], page: 1, pageSize: 20)

                // validate
                #expect(
                    res.results.compactMap(\.packageResult?.repositoryName).sorted() == ["1", "2"]
                )
            }
        }
    }

    @Test func keywordSearchFilter() async throws {
        try await withApp { app in
            // Setup
            let p1 = Package(url: "1", platformCompatibility: [.iOS])
            let p2 = Package(url: "2", platformCompatibility: [.macOS])
            try await [p1, p2].save(on: app.db)
            try await Repository(package: p1,
                                 defaultBranch: "main",
                                 keywords: ["kw1", "kw2"],
                                 name: "1",
                                 owner: "foo",
                                 summary: "test package").save(on: app.db)
            try await Repository(package: p2,
                                 defaultBranch: "main",
                                 keywords: ["kw1-2"],
                                 name: "2",
                                 owner: "bar",
                                 summary: "test package").save(on: app.db)
            try await Version(package: p1, packageName: "p1", reference: .branch("main"))
                .save(on: app.db)
            try await Version(package: p2, packageName: "p2", reference: .branch("main"))
                .save(on: app.db)
            try await Search.refresh(on: app.db)

            do {
                // MUT
                let res = try await Search.fetch(app.db, ["test", "keyword:kw1"], page: 1, pageSize: 20)

                // validate
                #expect(res.results.compactMap(\.packageResult?.repositoryName) == ["1"])
            }

            do {  // double check that leaving the filter term off selects both packages
                  // MUT
                let res = try await Search.fetch(app.db, ["test"], page: 1, pageSize: 20)

                // validate
                #expect(
                    res.results.compactMap(\.packageResult?.repositoryName).sorted() == ["1", "2"]
                )
            }
        }
    }

    @Test func lastActivitySearchFilter() async throws {
        try await withApp { app in
            // Setup
            let p1 = Package(url: "1", platformCompatibility: [.iOS])
            let p2 = Package(url: "2", platformCompatibility: [.macOS])
            try await [p1, p2].save(on: app.db)
            try await Repository(package: p1,
                                 defaultBranch: "main",
                                 lastCommitDate: .t0.adding(days: -1),
                                 name: "1",
                                 owner: "foo",
                                 summary: "test package").save(on: app.db)
            try await Repository(package: p2,
                                 defaultBranch: "main",
                                 lastCommitDate: .t0,
                                 name: "2",
                                 owner: "bar",
                                 summary: "test package").save(on: app.db)
            try await Version(package: p1, packageName: "p1", reference: .branch("main"))
                .save(on: app.db)
            try await Version(package: p2, packageName: "p2", reference: .branch("main"))
                .save(on: app.db)
            try await Search.refresh(on: app.db)

            do {
                // MUT
                let res = try await Search.fetch(app.db, ["test", "last_activity:<1970-01-01"], page: 1, pageSize: 20)

                // validate
                #expect(res.results.compactMap(\.packageResult?.repositoryName) == ["1"])
            }

            do {  // double check that leaving the filter term off selects both packages
                  // MUT
                let res = try await Search.fetch(app.db, ["test"], page: 1, pageSize: 20)

                // validate
                #expect(
                    res.results.compactMap(\.packageResult?.repositoryName).sorted() == ["1", "2"]
                )
            }
        }
    }

    @Test func lastCommitSearchFilter() async throws {
        try await withApp { app in
            // Setup
            let p1 = Package(url: "1", platformCompatibility: [.iOS])
            let p2 = Package(url: "2", platformCompatibility: [.macOS])
            try await [p1, p2].save(on: app.db)
            try await Repository(package: p1,
                                 defaultBranch: "main",
                                 lastCommitDate: .t0.adding(days: -1),
                                 name: "1",
                                 owner: "foo",
                                 summary: "test package").save(on: app.db)
            try await Repository(package: p2,
                                 defaultBranch: "main",
                                 lastCommitDate: .t0,
                                 name: "2",
                                 owner: "bar",
                                 summary: "test package").save(on: app.db)
            try await Version(package: p1, packageName: "p1", reference: .branch("main"))
                .save(on: app.db)
            try await Version(package: p2, packageName: "p2", reference: .branch("main"))
                .save(on: app.db)
            try await Search.refresh(on: app.db)

            do {
                // MUT
                let res = try await Search.fetch(app.db, ["test", "last_commit:<1970-01-01"], page: 1, pageSize: 20)

                // validate
                #expect(res.results.compactMap(\.packageResult?.repositoryName) == ["1"])
            }

            do {  // double check that leaving the filter term off selects both packages
                  // MUT
                let res = try await Search.fetch(app.db, ["test"], page: 1, pageSize: 20)

                // validate
                #expect(
                    res.results.compactMap(\.packageResult?.repositoryName).sorted() == ["1", "2"]
                )
            }
        }
    }

    @Test func licenseSearchFilter() async throws {
        try await withApp { app in
            // Setup
            let p1 = Package(url: "1", platformCompatibility: [.iOS])
            let p2 = Package(url: "2", platformCompatibility: [.macOS])
            try await [p1, p2].save(on: app.db)
            try await Repository(package: p1,
                                 defaultBranch: "main",
                                 license: .mit,
                                 name: "1",
                                 owner: "foo",
                                 summary: "test package").save(on: app.db)
            try await Repository(package: p2,
                                 defaultBranch: "main",
                                 license: .none,
                                 name: "2",
                                 owner: "bar",
                                 summary: "test package").save(on: app.db)
            try await Version(package: p1, packageName: "p1", reference: .branch("main"))
                .save(on: app.db)
            try await Version(package: p2, packageName: "p2", reference: .branch("main"))
                .save(on: app.db)
            try await Search.refresh(on: app.db)

            do {
                // MUT
                let res = try await Search.fetch(app.db, ["test", "license:mit"], page: 1, pageSize: 20)

                // validate
                #expect(res.results.compactMap(\.packageResult?.repositoryName) == ["1"])
            }

            do {
                // MUT
                let res = try await Search.fetch(app.db, ["test", "license:compatible"], page: 1, pageSize: 20)

                // validate
                #expect(res.results.compactMap(\.packageResult?.repositoryName) == ["1"])
            }

            do {  // double check that leaving the filter term off selects both packages
                  // MUT
                let res = try await Search.fetch(app.db, ["test"], page: 1, pageSize: 20)

                // validate
                #expect(
                    res.results.compactMap(\.packageResult?.repositoryName).sorted() == ["1", "2"]
                )
            }
        }
    }

    @Test func platformSearchFilter() async throws {
        try await withApp { app in
            // Setup
            let p1 = Package(url: "1", platformCompatibility: [.iOS])
            let p2 = Package(url: "2", platformCompatibility: [.macOS])
            try await [p1, p2].save(on: app.db)
            try await Repository(package: p1,
                                 defaultBranch: "main",
                                 name: "1",
                                 owner: "foo",
                                 summary: "test package").save(on: app.db)
            try await Repository(package: p2,
                                 defaultBranch: "main",
                                 name: "2",
                                 owner: "foo",
                                 summary: "test package").save(on: app.db)
            try await Version(package: p1, packageName: "p1", reference: .branch("main"))
                .save(on: app.db)
            try await Version(package: p2, packageName: "p2", reference: .branch("main"))
                .save(on: app.db)
            try await Search.refresh(on: app.db)

            do {
                // MUT
                let res = try await Search.fetch(app.db, ["test", "platform:ios"], page: 1, pageSize: 20)

                // validate
                #expect(res.results.compactMap(\.packageResult?.repositoryName) == ["1"])
            }

            do {  // double check that leaving the filter term off selects both packages
                  // MUT
                let res = try await Search.fetch(app.db, ["test"], page: 1, pageSize: 20)

                // validate
                #expect(
                    res.results.compactMap(\.packageResult?.repositoryName).sorted() == ["1", "2"]
                )
            }
        }
    }

    @Test func starsSearchFilter() async throws {
        try await withApp { app in
            // Setup
            let p1 = Package(url: "1", platformCompatibility: [.iOS])
            let p2 = Package(url: "2", platformCompatibility: [.macOS])
            try await [p1, p2].save(on: app.db)
            try await Repository(package: p1,
                                 defaultBranch: "main",
                                 name: "1",
                                 owner: "foo",
                                 stars: 10,
                                 summary: "test package").save(on: app.db)
            try await Repository(package: p2,
                                 defaultBranch: "main",
                                 name: "2",
                                 owner: "bar",
                                 summary: "test package").save(on: app.db)
            try await Version(package: p1, packageName: "p1", reference: .branch("main"))
                .save(on: app.db)
            try await Version(package: p2, packageName: "p2", reference: .branch("main"))
                .save(on: app.db)
            try await Search.refresh(on: app.db)

            do {
                // MUT
                let res = try await Search.fetch(app.db, ["test", "stars:>5"], page: 1, pageSize: 20)

                // validate
                #expect(res.results.compactMap(\.packageResult?.repositoryName) == ["1"])
            }

            do {  // double check that leaving the filter term off selects both packages
                  // MUT
                let res = try await Search.fetch(app.db, ["test"], page: 1, pageSize: 20)

                // validate
                #expect(
                    res.results.compactMap(\.packageResult?.repositoryName).sorted() == ["1", "2"]
                )
            }
        }
    }

    @Test func productTypeFilter() async throws {
        try await withApp { app in
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
            try await Search.refresh(on: app.db)

            do {
                // MUT
                let res = try await Search.fetch(app.db, ["test", "product:plugin"], page: 1, pageSize: 20)

                // validate
                #expect(res.results.count == 1)
                #expect(
                    res.results.compactMap(\.packageResult?.repositoryName) == ["2"]
                )
            }

            do {
                // MUT
                let res = try await Search.fetch(app.db, ["test"], page: 1, pageSize: 20)

                // validate
                #expect(res.results.count == 2)
                #expect(
                    res.results.compactMap(\.packageResult?.repositoryName) == ["1", "2"]
                )
            }
        }
    }

    @Test func productTypeFilter_macro() async throws {
        try await withApp { app in
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
                try await Target(version: v, name: "t1", type: .regular).save(on: app.db)
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
                try await Target(version: v, name: "t2", type: .macro).save(on: app.db)
            }
            try await Search.refresh(on: app.db)

            do {
                // MUT
                let res = try await Search.fetch(app.db, ["test", "product:macro"], page: 1, pageSize: 20)

                // validate
                #expect(res.results.count == 1)
                #expect(
                    res.results.compactMap(\.packageResult?.repositoryName) == ["2"]
                )
            }

            do {
                // MUT
                let res = try await Search.fetch(app.db, ["test"], page: 1, pageSize: 20)

                // validate
                #expect(res.results.count == 2)
                #expect(
                    res.results.compactMap(\.packageResult?.repositoryName) == ["1", "2"]
                )
            }
        }
    }

    @Test func SearchFilter_error() async throws {
        // Test error handling in case of an invalid filter
        try await withApp { app in
            // Setup
            let p1 = Package(url: "1", platformCompatibility: [.iOS])
            let p2 = Package(url: "2", platformCompatibility: [.macOS])
            try await [p1, p2].save(on: app.db)
            try await Repository(package: p1,
                                 defaultBranch: "main",
                                 license: .mit,
                                 name: "1",
                                 owner: "foo",
                                 summary: "test package").save(on: app.db)
            try await Repository(package: p2,
                                 defaultBranch: "main",
                                 license: .none,
                                 name: "2",
                                 owner: "bar",
                                 summary: "test package").save(on: app.db)
            try await Version(package: p1, packageName: "p1", reference: .branch("main"))
                .save(on: app.db)
            try await Version(package: p2, packageName: "p2", reference: .branch("main"))
                .save(on: app.db)
            try await Search.refresh(on: app.db)

            // MUT
            let res = try await Search.fetch(app.db, ["test", "license:>mit"], page: 1, pageSize: 20)

            // validate
            #expect(res.results.compactMap(\.packageResult?.repositoryName) == [])
        }
    }

    @Test func hasDocs_external_docs() async throws {
        // Ensure external docs as listed as having docs
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2702
        try await withApp { app in
            let pkg = Package(url: "1")
            try await pkg.save(on: app.db)
            try await Repository(package: pkg,
                                 defaultBranch: "main",
                                 name: "1",
                                 owner: "foo").save(on: app.db)
            try await Version(package: pkg,
                              commit: "sha",
                              commitDate: .t0,
                              packageName: "1",
                              reference: .branch("main"),
                              spiManifest: .init(externalLinks: .init(documentation: "doc link")))
            .save(on: app.db)
            try await Search.refresh(on: app.db)

            // MUT
            let res = try await Search.fetch(app.db, ["1"], page: 1, pageSize: 20)

            // validate
            #expect(res.results.first?.package?.hasDocs == true)
        }
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
