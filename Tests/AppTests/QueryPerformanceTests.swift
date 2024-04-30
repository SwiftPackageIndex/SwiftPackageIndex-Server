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

@testable import App

import SQLKit
import Vapor
import XCTest


class QueryPerformanceTests: XCTestCase {
    var app: Application!

    override func setUpWithError() throws {
        try super.setUpWithError()

        try XCTSkipUnless(runQueryPerformanceTests)

        // Update db settings for CI runs in
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/settings/secrets/actions
        // or in `.env.staging` for local runs.
        self.app = Application(.staging)
        self.app.logger.logLevel = Environment.get("LOG_LEVEL")
            .flatMap(Logger.Level.init(rawValue:)) ?? .warning
        let host = try configure(app)

        XCTAssert(host.hasPrefix("spi-dev-db"), "was: \(host)")
        XCTAssert(host.hasSuffix("postgres.database.azure.com"), "was: \(host)")
    }

    func test_01_Search_packageMatchQuery() async throws {
        let query = Search.packageMatchQueryBuilder(on: app.db, terms: ["a"], filters: [])
        try await assertQueryPerformance(query, expectedCost: 1400, variation: 150)
    }

    func test_02_Search_keywordMatchQuery() async throws {
        let query = Search.keywordMatchQueryBuilder(on: app.db, terms: ["a"])
        try await assertQueryPerformance(query, expectedCost: 5400, variation: 200)
    }

    func test_03_Search_authorMatchQuery() async throws {
        let query = Search.authorMatchQueryBuilder(on: app.db, terms: ["a"])
        try await assertQueryPerformance(query, expectedCost: 1000, variation: 50)
    }

    func test_04_Search_query_noFilter() async throws {
        let query = try Search.query(app.db, ["a"], page: 1)
            .unwrap()
        try await assertQueryPerformance(query, expectedCost: 7400, variation: 200)
    }

    func test_05_Search_query_authorFilter() async throws {
        let filter = try AuthorSearchFilter(expression: .init(operator: .is, value: "apple"))
        let query = try Search.query(app.db, ["a"], filters: [filter], page: 1)
            .unwrap()
        try await assertQueryPerformance(query, expectedCost: 7100, variation: 200)
    }

    func test_06_Search_query_keywordFilter() async throws {
        let filter = try KeywordSearchFilter(expression: .init(operator: .is, value: "apple"))
        let query = try Search.query(app.db, ["a"], filters: [filter], page: 1)
            .unwrap()
        try await assertQueryPerformance(query, expectedCost: 7200, variation: 200)
    }

    func test_07_Search_query_lastActicityFilter() async throws {
        let filter = try LastActivitySearchFilter(expression: .init(operator: .greaterThan, value: "2000-01-01"))
        let query = try Search.query(app.db, ["a"], filters: [filter], page: 1)
            .unwrap()
        try await assertQueryPerformance(query, expectedCost: 7400, variation: 200)
    }

    func test_08_Search_query_licenseFilter() async throws {
        let filter = try LicenseSearchFilter(expression: .init(operator: .is, value: "mit"))
        let query = try Search.query(app.db, ["a"], filters: [filter], page: 1)
            .unwrap()
        try await assertQueryPerformance(query, expectedCost: 7300, variation: 200)
    }

    func test_09_Search_query_platformFilter() async throws {
        let filter = try PlatformSearchFilter(expression: .init(operator: .is, value: "macos,ios"))
        let query = try Search.query(app.db, ["a"], filters: [filter], page: 1)
            .unwrap()
        try await assertQueryPerformance(query, expectedCost: 7100, variation: 200)
    }

    func test_10_Search_query_productTypeFilter() async throws {
        let filter = try ProductTypeSearchFilter(expression: .init(operator: .is, value: "plugin"))
        let query = try Search.query(app.db, ["a"], filters: [filter], page: 1)
            .unwrap()
        try await assertQueryPerformance(query, expectedCost: 7100, variation: 200)
    }

    func test_11_Search_query_starsFilter() async throws {
        let filter = try StarsSearchFilter(expression: .init(operator: .greaterThan, value: "5"))
        let query = try Search.query(app.db, ["a"], filters: [filter], page: 1)
            .unwrap()
        try await assertQueryPerformance(query, expectedCost: 7300, variation: 300)
    }

    func test_12_Search_refresh() async throws {
        // We can't "explain analyze" the refresh itself so we need to measure the underlying
        // query.
        // Unfortunately, this means it'll need to be kept in sync when updating the search
        // view.
        guard let db = app.db as? SQLDatabase else {
            XCTFail()
            return
        }
        let query = db.raw("""
            -- v12
            SELECT
              p.id AS package_id,
              p.platform_compatibility,
              p.score,
              r.keywords,
              r.last_commit_date,
              r.license,
              r.name AS repo_name,
              r.owner AS repo_owner,
              r.stars,
              r.last_activity_at,
              r.summary,
              v.package_name,
              (
                ARRAY_LENGTH(doc_archives, 1) >= 1
                OR spi_manifest->'external_links'->'documentation' IS NOT NULL
              ) AS has_docs,
              ARRAY(
                SELECT DISTINCT JSONB_OBJECT_KEYS(type) FROM products WHERE products.version_id = v.id
                UNION
                SELECT * FROM (
                  SELECT DISTINCT JSONB_OBJECT_KEYS(type) AS "type" FROM targets
                  WHERE targets.version_id = v.id) AS macro_targets
                WHERE type = 'macro'
              ) AS product_types,
              ARRAY(SELECT DISTINCT name FROM products WHERE products.version_id = v.id) AS product_names,
              TO_TSVECTOR(CONCAT_WS(' ', COALESCE(v.package_name, ''), r.name, COALESCE(r.summary, ''), ARRAY_TO_STRING(r.keywords, ' '))) AS tsvector
            FROM packages p
              JOIN repositories r ON r.package_id = p.id
              JOIN versions v ON v.package_id = p.id
            WHERE v.reference ->> 'branch' = r.default_branch
            """)
        try await assertQueryPerformance(query, expectedCost: 81_000, variation: 5000)
    }

}


// MARK: - Query plan helpers


private extension Environment {
    static var staging: Self { .init(name: "staging") }
}


struct SQLExplain: SQLExpression {
    let query: any SQLExpression
    init(_ builder: SQLQueryBuilder) {
        self.query = builder.query
    }
    func serialize(to serializer: inout SQLSerializer) {
        serializer.write("EXPLAIN ANALYZE ")
        query.serialize(to: &serializer)
    }
}


private extension QueryPerformanceTests {

    func assertQueryPerformance(_ query: SQLQueryBuilder,
                                expectedCost: Double,
                                variation: Double = 0,
                                filePath: StaticString = #filePath,
                                lineNumber: UInt = #line,
                                testName: String = #function) async throws {
        let explain = SQLExplain(query)
        let result = QueueIsolated<[String]>([])
        try await (app.db as! SQLDatabase).execute(sql: explain) { row in
            let res = (try? row.decode(column: "QUERY PLAN", as: String.self)) ?? "-"
            result.withValue { $0.append(res) }
        }
        let queryPlan = result.value.joined(separator: "\n")

        let parsedPlan = try QueryPlan(queryPlan)
        print("ℹ️ TEST:        \(testName)")
        if parsedPlan.cost.total <= expectedCost {
            print("ℹ️ COST:        \(parsedPlan.cost.total)")
        } else {
            print("⚠️ COST:        \(parsedPlan.cost.total)")
        }
        print("ℹ️ EXPECTED:    \(expectedCost) ± \(variation)")
        print("ℹ️ ACTUAL TIME: \(parsedPlan.actualTime.total)ms")

        switch parsedPlan.cost.total {
            case ..<10.0:
                if isRunningInCI {
                    print("::error file=\(filePath),line=\(lineNumber),title=\(testName)::Cost very low \(parsedPlan.cost.total) - did you run the query against an empty database?")
                }
                XCTFail("""
                        Cost very low \(parsedPlan.cost.total) - did you run the query against an empty database?

                        \(queryPlan)
                        """,
                        file: filePath,
                        line: lineNumber)
            case ..<expectedCost:
                break
            case ..<(expectedCost + variation):
                if isRunningInCI {
                    print("::warning file=\(filePath),line=\(lineNumber),title=\(testName)::Total cost of \(parsedPlan.cost.total) close to the threshold of \(expectedCost + variation)")
                }
            default:
                if isRunningInCI {
                    print("::error file=\(filePath),line=\(lineNumber),title=\(testName)::Total cost of \(parsedPlan.cost.total) above the threshold of \(expectedCost + variation)")
                }
                XCTFail("""
                        Total cost of \(parsedPlan.cost.total) above the threshold of \(expectedCost + variation)

                        Query plan:

                        \(queryPlan)
                        """,
                        file: filePath,
                        line: lineNumber)
        }
    }

}
