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

import Parsing
import SQLKit
import Vapor
import XCTest


class QueryPerformanceTests: XCTestCase {
    var app: Application!

    override func setUpWithError() throws {
        try super.setUpWithError()

        try XCTSkipUnless(runQueryPerformanceTests)

        self.app = Application(.staging)
        self.app.logger.logLevel = Environment.get("LOG_LEVEL")
            .flatMap(Logger.Level.init(rawValue:)) ?? .warning
        let host = try configure(app)

        XCTAssert(host.hasSuffix("postgres.database.azure.com"), "was: \(host)")
    }

    func test_QueryPlan_cost_parse() throws {
        var input = "cost=1.05..12.06 rows=1 width=205"[...]
        XCTAssertEqual(try QueryPlan.cost.parse(&input),
                       .init(firstRow: 1.05, total: 12.06))
        XCTAssertEqual(input, "")
    }

    func test_QueryPlan_actualTime_parse() throws {
        var input = "actual time=8.340..44.485 rows=121 loops=1"[...]
        XCTAssertEqual(try QueryPlan.actualTime.parse(&input),
                       .init(firstRow: 8.34, total: 44.485))
        XCTAssertEqual(input, "")
    }

    func test_QueryPlan_parser() throws {
        var input = "Append  (cost=412.37..3826.71 rows=81 width=308) (actual time=8.340..44.485 rows=121 loops=1)"[...]
        XCTAssertEqual(try QueryPlan.parser.parse(&input),
                       .init(cost: .init(firstRow: 412.37, total: 3826.71),
                             actualTime: .init(firstRow: 8.34, total: 44.485)))
        XCTAssertEqual(input, "")
    }

    func test_Search_packageMatchQuery() async throws {
        let query = Search.packageMatchQueryBuilder(on: app.db, terms: ["a"], filters: [])
        try await assertQueryPerformance(query, expectedCost: 660, variation: 50)
    }

    func test_Search_keywordMatchQuery() async throws {
        let query = Search.keywordMatchQueryBuilder(on: app.db, terms: ["a"])
        try await assertQueryPerformance(query, expectedCost: 2990, variation: 100)
    }

    func test_Search_authorMatchQuery() async throws {
        let query = Search.authorMatchQueryBuilder(on: app.db, terms: ["a"])
        try await assertQueryPerformance(query, expectedCost: 420, variation: 50)
    }

    func test_Search_query_noFilter() async throws {
        let query = try Search.query(app.db, ["a"],
                                     page: 1, pageSize: Constants.resultsPageSize)
            .unwrap()
        try await assertQueryPerformance(query, expectedCost: 3910, variation: 100)
    }

    func test_Search_query_authorFilter() async throws {
        let filter = try AuthorSearchFilter(expression: .init(operator: .is, value: "apple"))
        let query = try Search.query(app.db, ["a"], filters: [filter],
                                     page: 1, pageSize: Constants.resultsPageSize)
            .unwrap()
        try await assertQueryPerformance(query, expectedCost: 3680, variation: 100)
    }

    func test_Search_query_keywordFilter() async throws {
        let filter = try KeywordSearchFilter(expression: .init(operator: .is, value: "apple"))
        let query = try Search.query(app.db, ["a"], filters: [filter],
                                     page: 1, pageSize: Constants.resultsPageSize)
            .unwrap()
        try await assertQueryPerformance(query, expectedCost: 3920, variation: 100)
    }

    func test_Search_query_lastActicityFilter() async throws {
        let filter = try LastActivitySearchFilter(expression: .init(operator: .greaterThan, value: "2000-01-01"))
        let query = try Search.query(app.db, ["a"], filters: [filter],
                                     page: 1, pageSize: Constants.resultsPageSize)
            .unwrap()
        try await assertQueryPerformance(query, expectedCost: 3920, variation: 100)
    }

    func test_Search_query_licenseFilter() async throws {
        let filter = try LicenseSearchFilter(expression: .init(operator: .is, value: "mit"))
        let query = try Search.query(app.db, ["a"], filters: [filter],
                                     page: 1, pageSize: Constants.resultsPageSize)
            .unwrap()
        try await assertQueryPerformance(query, expectedCost: 3800, variation: 100)
    }

    func test_Search_query_platformFilter() async throws {
        let filter = try PlatformSearchFilter(expression: .init(operator: .is, value: "macos,ios"))
        let query = try Search.query(app.db, ["a"], filters: [filter],
                                     page: 1, pageSize: Constants.resultsPageSize)
            .unwrap()
        try await assertQueryPerformance(query, expectedCost: 3840, variation: 100)
    }

    func test_Search_query_starsFilter() async throws {
        let filter = try StarsSearchFilter(expression: .init(operator: .greaterThan, value: "5"))
        let query = try Search.query(app.db, ["a"], filters: [filter],
                                     page: 1, pageSize: Constants.resultsPageSize)
            .unwrap()
        try await assertQueryPerformance(query, expectedCost: 3830, variation: 100)
    }

}


// MARK: - Query plan helpers


private extension Environment {
    static var staging: Self { .init(name: "staging") }
}


public struct SQLExplain: SQLExpression {
    public var select: SQLSelectBuilder
    public init(_ select: SQLSelectBuilder) {
        self.select = select
    }
    public func serialize(to serializer: inout SQLSerializer) {
        serializer.write("EXPLAIN ANALYZE ")
        select.select.serialize(to: &serializer)
    }
}


private extension QueryPerformanceTests {

    func assertQueryPerformance(_ query: SQLSelectBuilder,
                                expectedCost: Double,
                                variation: Double = 0,
                                filePath: StaticString = #filePath,
                                lineNumber: UInt = #line) async throws {
        let explain = SQLExplain(query)
        var result = [String]()
        try await (app.db as! SQLDatabase).execute(sql: explain) { row in
            let res = (try? row.decode(column: "QUERY PLAN", as: String.self)) ?? "-"
            result.append(res)
        }
        let queryPlan = result.joined(separator: "\n")

        let parsedPlan = try QueryPlan(queryPlan)
        print("COST: \(parsedPlan.cost)")
        print("ACTUAL TIME: \(parsedPlan.actualTime)")

        switch parsedPlan.cost.total {
            case ..<10.0:
                XCTFail("""
                        Cost very low \(parsedPlan.cost.total) - did you run the query against an empty database?

                        \(queryPlan)
                        """,
                        file: filePath,
                        line: lineNumber)
            case ..<(expectedCost + variation):
                break
            default:
                XCTFail("""
                        Total cost of \(parsedPlan.cost.total) above threshold of \(expectedCost + variation) (incl variation)

                        Query plan:

                        \(queryPlan)
                        """,
                        file: filePath,
                        line: lineNumber)
        }
    }

}


private struct Cost {
    var firstRow: Double
    var total: Double
}


private struct Details {
    var rows: Int
    var width: Int
}


struct QueryPlan: Equatable {
    var cost: Cost
    var actualTime: ActualTime

    struct Cost: Equatable {
        var firstRow: Double
        var total: Double
    }

    // Parsing: cost=1.05..1.06 rows=1 width=205
    static let cost = Parse {
        "cost="
        Double.parser()
        ".."
        Double.parser()
        Skip { Whitespace() }
        Skip {
            "rows="
            Int.parser()
            Skip { Whitespace() }
            "width="
            Int.parser()
        }
    }.map(Cost.init)

    struct ActualTime: Equatable {
        var firstRow: Double
        var total: Double
    }

    // Parsing: actual time=8.340..44.485 rows=121 loops=1
    static let actualTime = Parse {
        "actual time="
        Double.parser()
        ".."
        Double.parser()
        Skip { Whitespace() }
        Skip {
            "rows="
            Int.parser()
            Skip { Whitespace() }
            "loops="
            Int.parser()
        }
    }.map(ActualTime.init)

    // Parsing: Append  (cost=412.37..3826.71 rows=81 width=308) (actual time=8.340..44.485 rows=121 loops=1)
    static let parser = Parse {
        Skip {
            OneOf {
                "Append"
                "Limit"
                "Sort"
            }
            Whitespace()
            "("
        }
        cost
        Skip {
            ")"
            Whitespace()
            "("
        }
        actualTime
        Skip { ")" }
    }.map(Self.init)
}


extension QueryPlan {
    init(_ queryPlan: String) throws {
        self = try Self.parser.parse(queryPlan)
    }
}
