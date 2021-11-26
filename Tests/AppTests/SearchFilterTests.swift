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

import SQLKit
import XCTVapor
import SnapshotTesting

class SearchFilterTests: AppTestCase {
    
    func test_allSearchFilters() {
        XCTAssertEqual(
            SearchFilterParser
                .allSearchFilters
                .map { $0.key }
                .sorted(),
            [ "last_commit", "license", "stars" ]
        )
    }
    
    func test_parseTerm() {
        let parser = SearchFilterParser()
        
        func mockParse(term: String) throws -> MockSearchFilter {
            try XCTUnwrap(parser.parse(term: term, allFilters: [
                MockSearchFilter.self
            ]) as? MockSearchFilter)
        }
        
        do { // No colon
            XCTAssertNil(parser.parse(term: "a"))
        }
        
        do { // Too many colons
            XCTAssertNil(parser.parse(term: "a:b:c"))
        }
        
        do { // Comparison method
            try XCTAssertEqual(mockParse(term: "mock:1").comparison, .match)
            try XCTAssertEqual(mockParse(term: "mock:>1").comparison, .greaterThan)
            try XCTAssertEqual(mockParse(term: "mock:<1").comparison, .lessThan)
            try XCTAssertEqual(mockParse(term: "mock:!1").comparison, .negativeMatch)
        }
        
        do { // Correct value
            try XCTAssertEqual(mockParse(term: "mock:test").value, "test")
            try XCTAssertEqual(mockParse(term: "mock:!test").value, "test")
            
            // terms are usually tokenised based on spaces meaning this should, in theory,
            // never happen. However, the filter system does support it.
            try XCTAssertEqual(mockParse(term: "mock:!with space").value, "with space")
        }
        
        do { // No valid filter
            XCTAssertNil(parser.parse(term: "invalid:true"))
        }
        
        do { // Valid filter
            XCTAssertTrue(parser.parse(term: "stars:5") is StarsSearchFilter)
        }
        
    }
    
    func test_separateTermsAndFilters() {
        let parser = SearchFilterParser()
        let output = parser.split(terms: ["a", "b", "invalid:true", "stars:5"])
        
        XCTAssertEqual(output.terms.sorted(), ["a", "b", "invalid:true"])
        
        XCTAssertEqual(output.filters.count, 1)
        XCTAssertTrue(output.filters[0] is StarsSearchFilter)
    }
    
    func test_binaryOperator() {
        let matrix: [(SearchFilterComparison, Bool, SQLBinaryOperator, UInt)] = [
            (.greaterThan, false, .greaterThan, #line),
            (.lessThan, false, .lessThan, #line),
            (.match, false, .equal, #line),
            (.negativeMatch, false, .notEqual, #line),
            
            (.greaterThan, true, .greaterThan, #line),
            (.lessThan, true, .lessThan, #line),
            (.match, true, .in, #line),
            (.negativeMatch, true, .notIn, #line),
        ]
        
        matrix.forEach { comparison, isSet, sqlOperator, line in
            XCTAssertEqual(
                comparison.binaryOperator(isSet: isSet),
                sqlOperator,
                line: line
            )
        }
    }
    
    // MARK: Filters
    
    func test_starsFilter() throws {
        XCTAssertEqual(StarsSearchFilter.key, "stars")
        XCTAssertThrowsError(try StarsSearchFilter(value: "one", comparison: .match))
        XCTAssertEqual(try StarsSearchFilter(value: "1", comparison: .match).value, 1)
        XCTAssertEqual(
            try StarsSearchFilter(value: "1", comparison: .match).createViewModel().description,
            "stars matches 1"
        )
        
        let filter = try StarsSearchFilter(value: "1", comparison: .greaterThan)
        let builder = SQLSelectBuilder(on: app.db as! SQLDatabase)
            .where(searchFilters: [filter])
        let sql = renderSQL(builder, resolveBinds: true)
        _assertInlineSnapshot(matching: sql, as: .lines, with: """
        SELECT  WHERE ("stars" > '1')
        """)
    }
    
    func test_licenseFilter() throws {
        XCTAssertEqual(LicenseSearchFilter.key, "license")
        XCTAssertThrowsError(try LicenseSearchFilter(value: "appStoreCompatible", comparison: .greaterThan))
        XCTAssertEqual(try LicenseSearchFilter(value: "appStoreCompatible", comparison: .match).filterType, .appStoreCompatible)
        XCTAssertEqual(
            try LicenseSearchFilter(value: "appStoreCompatible", comparison: .match).createViewModel().description,
            "license matches appStoreCompatible"
        )
        
        do {
            let filter = try LicenseSearchFilter(value: "appStoreCompatible", comparison: .match)
            let builder = SQLSelectBuilder(on: app.db as! SQLDatabase)
                .where(searchFilters: [filter])
            let sql = renderSQL(builder, resolveBinds: true)
            _assertInlineSnapshot(matching: sql, as: .lines, with: """
            SELECT  WHERE ("license" IN ('afl-3.0', 'apache-2.0', 'artistic-2.0', 'bsd-2-clause', 'bsd-3-clause', 'bsd-3-clause-clear', 'bsl-1.0', 'cc', 'cc0-1.0', 'afl-3.0'0, 'afl-3.0'1, 'afl-3.0'2, 'afl-3.0'3, 'afl-3.0'4, 'afl-3.0'5, 'afl-3.0'6, 'afl-3.0'7, 'afl-3.0'8, 'afl-3.0'9, 'apache-2.0'0, 'apache-2.0'1, 'apache-2.0'2, 'apache-2.0'3, 'apache-2.0'4))
            """)
        }
        
        do {
            let filter = try LicenseSearchFilter(value: "mit", comparison: .match)
            let builder = SQLSelectBuilder(on: app.db as! SQLDatabase)
                .where(searchFilters: [filter])
            let sql = renderSQL(builder, resolveBinds: true)
            _assertInlineSnapshot(matching: sql, as: .lines, with: """
            SELECT  WHERE ("license" = 'mit')
            """)
        }
        
    }
    
    func test_lastCommitFilter() throws {
        XCTAssertEqual(LastCommitSearchFilter.key, "last_commit")
        XCTAssertThrowsError(try LastCommitSearchFilter(value: "23rd June 2021", comparison: .match))
        XCTAssertEqual(try LastCommitSearchFilter(value: "1970-01-01", comparison: .match).date, .t0)
        XCTAssertEqual(
            try LastCommitSearchFilter(value: "1970-01-01", comparison: .match).createViewModel().description,
            "last_commit matches 1970-01-01"
        )

        let filter = try LastCommitSearchFilter(value: "1970-01-01", comparison: .match)
        let builder = SQLSelectBuilder(on: app.db as! SQLDatabase)
            .where(searchFilters: [filter])
        let sql = renderSQL(builder, resolveBinds: true)
        _assertInlineSnapshot(matching: sql, as: .lines, with: """
        SELECT  WHERE ("last_commit_date" = '1970-01-01')
        """)
    }
    
    // MARK: Mock
    
    struct MockSearchFilter: SearchFilter {
        static var key: String = "mock"
        
        let value: String
        let comparison: SearchFilterComparison
        
        init(value: String, comparison: SearchFilterComparison) throws {
            self.value = value
            self.comparison = comparison
        }
        
        func `where`(_ builder: SQLPredicateGroupBuilder) -> SQLPredicateGroupBuilder {
            return builder
        }
        
        func createViewModel() -> SearchFilterViewModel {
            .init(key: Self.key, comparison: comparison, value: value)
        }
    }
    
}

extension SearchFilterViewModel: CustomStringConvertible {
    public var description: String {
        "\(key) \(comparison.userFacingString) \(value)"
    }
}
