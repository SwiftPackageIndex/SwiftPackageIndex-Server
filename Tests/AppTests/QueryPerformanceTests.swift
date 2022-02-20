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

    func test_packageMatchQuery() async throws {
        let query = Search.packageMatchQueryBuilder(on: app.db, terms: ["test"], filters: [])
        try await assertQueryPerformance(query, expectedCost: 270, variation: 50)
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
        serializer.write("EXPLAIN ")
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

        let (cost, _) = try queryPlanParser.parse(queryPlan)

        switch cost.total {
            case ..<10.0:
                XCTFail("""
                        Cost very low \(cost.total) - did you run the query against an empty database?

                        \(queryPlan)
                        """,
                        file: filePath,
                        line: lineNumber)
            case 10.0 ..< expectedCost + variation:
                break
            default:
                XCTFail("""
                        Total cost of \(cost.total) above threshold of \(expectedCost + variation) (incl variation)

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


private let queryPlanParser = Parse {
    // "Sort  (cost=1.05..1.06 rows=1 width=205)\n"
    Skip {
        "Sort"
        Whitespace()
        "("
    }

    Parse {
        "cost="
        Double.parser()
        ".."
        Double.parser()
    }.map(Cost.init)

    Skip { Whitespace() }

    Parse {
        "rows="
        Int.parser()
        Skip { Whitespace() }
        "width="
        Int.parser()
    }.map(Details.init)
    ")"
}
