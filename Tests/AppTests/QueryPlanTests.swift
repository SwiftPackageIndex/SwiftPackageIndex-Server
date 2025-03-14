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

import Testing

@preconcurrency import Parsing


extension AllTests.QueryPlanTests {
    
    @Test func cost_parse() throws {
        #expect(
            try QueryPlan.cost.parse("cost=1.05..12.06 rows=1 width=205") == .init(firstRow: 1.05, total: 12.06)
        )
    }

    @Test func actualTime_parse() throws {
        #expect(
            try QueryPlan.actualTime.parse("actual time=8.340..44.485 rows=121 loops=1") == .init(firstRow: 8.34, total: 44.485)
        )
    }

    @Test func parser() throws {
        #expect(
            try QueryPlan.parser.parse("Append  (cost=412.37..3826.71 rows=81 width=308) (actual time=8.340..44.485 rows=121 loops=1)") == .init(cost: .init(firstRow: 412.37, total: 3826.71),
                  actualTime: .init(firstRow: 8.34, total: 44.485))
        )
    }

    @Test func QueryPlan_init() throws {
        let input = #"""
            Sort  (cost=555.79..566.89 rows=4439 width=318) (actual time=53.590..53.927 rows=4330 loops=1)
              Sort Key: ((lower(package_name) = 'a'::text)) DESC, score DESC, package_name
              Sort Method: quicksort  Memory: 1888kB
              ->  Seq Scan on search  (cost=0.00..286.88 rows=4439 width=318) (actual time=0.118..26.507 rows=4330 loops=1)
                    Filter: ((repo_owner IS NOT NULL) AND (repo_name IS NOT NULL) AND (concat_ws(' '::text, package_name, COALESCE(summary, ''::text), repo_name, repo_owner, array_to_string(keywords, ' '::text)) ~* 'a'::text))
                    Rows Removed by Filter: 109
            Planning Time: 0.853 ms
            Execution Time: 55.151 ms
            """#
        #expect(try QueryPlan(input) == .init(cost: .init(firstRow: 555.79, total: 566.89),
                             actualTime: .init(firstRow: 53.590, total: 53.927)))
    }

}


// MARK: - Parsing helpers


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
                "Gather"
                "Hash Join"
                "Limit"
                "Nested Loop"
                "Sort"
                "Unique"
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
        Skip { Optionally { Rest() } }
    }.map(Self.init)
}


extension QueryPlan {
    init(_ queryPlan: String) throws {
        self = try Self.parser.parse(queryPlan)
    }
}
