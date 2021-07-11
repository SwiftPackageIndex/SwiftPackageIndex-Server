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
            [ "license", "stars", "updated" ]
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
        let output = parser.separate(terms: ["a", "b", "invalid:true", "stars:5"])
        
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
        
        let filter = try StarsSearchFilter(value: "1", comparison: .greaterThan)
        let sql = renderSQL(MockPredicateBuilder.apply(filter: filter), resolveBinds: true)
        _assertInlineSnapshot(matching: sql, as: .lines, with: """
        "stars" > '1'
        """)
    }
    
    func test_licenseFilter() throws {
        XCTAssertEqual(LicenseSearchFilter.key, "license")
        XCTAssertThrowsError(try LicenseSearchFilter(value: "mit", comparison: .match))
        XCTAssertThrowsError(try LicenseSearchFilter(value: "compatible", comparison: .greaterThan))
        XCTAssertEqual(try LicenseSearchFilter(value: "compatible", comparison: .match).filterType, .compatible)
        
        let filter = try LicenseSearchFilter(value: "compatible", comparison: .match)
        let sql = renderSQL(MockPredicateBuilder.apply(filter: filter), resolveBinds: true)
        _assertInlineSnapshot(matching: sql, as: .lines, with: """
        "license" IN ('afl-3.0', 'apache-2.0', 'artistic-2.0', 'bsd-2-clause', 'bsd-3-clause', 'bsd-3-clause-clear', 'bsl-1.0', 'cc', 'cc0-1.0', 'afl-3.0'0, 'afl-3.0'1, 'afl-3.0'2, 'afl-3.0'3, 'afl-3.0'4, 'afl-3.0'5, 'afl-3.0'6, 'afl-3.0'7, 'afl-3.0'8, 'afl-3.0'9, 'apache-2.0'0, 'apache-2.0'1, 'apache-2.0'2, 'apache-2.0'3, 'apache-2.0'4)
        """)
    }
    
    func test_updatedFilter() throws {
        XCTAssertEqual(UpdatedSearchFilter.key, "updated")
        XCTAssertThrowsError(try UpdatedSearchFilter(value: "23rd June 2021", comparison: .match))
        XCTAssertEqual(try UpdatedSearchFilter(value: "2001-01-01", comparison: .match).date, Date(timeIntervalSinceReferenceDate: 0))
        
        let filter = try UpdatedSearchFilter(value: "2001-01-01", comparison: .match)
        let sql = renderSQL(MockPredicateBuilder.apply(filter: filter), resolveBinds: true)
        _assertInlineSnapshot(matching: sql, as: .lines, with: """
        "last_commit_date" = '2001-01-01'
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
        
        func query(_ builder: SQLPredicateGroupBuilder) -> SQLPredicateGroupBuilder {
            return builder
        }
    }
    
    class MockPredicateBuilder: SQLPredicateBuilder {
        var predicate: SQLExpression?
        
        static func apply(filter: SearchFilter) -> SQLBinaryExpression {
            let groupExpression = MockPredicateBuilder()
                .where(group: filter.query(_:))
                .predicate as? SQLGroupExpression
            
            return groupExpression!.expressions[0] as! SQLBinaryExpression
        }
    }
    
}
