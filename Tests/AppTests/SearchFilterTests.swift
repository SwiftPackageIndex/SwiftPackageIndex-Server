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
import XCTest
import XCTVapor


class SearchFilterTests: AppTestCase {

    func test_SearchFilterKey_searchFilter() throws {
        // Ensure all `SearchFilter.Key`s are wired correctly to their
        // `SearchFilterProtocol.Type`s (by roundtripping through the key values)
        XCTAssertEqual(SearchFilter.Key.allCases
                        .map { $0.searchFilter.key }, [
                            .author,
                            .keyword,
                            .lastActivity,
                            .lastCommit,
                            .license,
                            .platform,
                            .stars,
                            .productType
                        ])
    }

    func test_Expression_init() throws {
        XCTAssertEqual(SearchFilter.Expression(predicate: ">5"),
                       .init(operator: .greaterThan, value: "5"))
        XCTAssertEqual(SearchFilter.Expression(predicate: ">=5"),
                       .init(operator: .greaterThanOrEqual, value: "5"))
        XCTAssertEqual(SearchFilter.Expression(predicate: "<5"),
                       .init(operator: .lessThan, value: "5"))
        XCTAssertEqual(SearchFilter.Expression(predicate: "<=5"),
                       .init(operator: .lessThanOrEqual, value: "5"))
        XCTAssertEqual(SearchFilter.Expression(predicate: "!5"),
                       .init(operator: .isNot, value: "5"))
        XCTAssertEqual(SearchFilter.Expression(predicate: "5"),
                       .init(operator: .is, value: "5"))
        XCTAssertEqual(SearchFilter.Expression(predicate: ""), nil)
        XCTAssertEqual(SearchFilter.Expression(predicate: "!with space"),
                       .init(operator: .isNot, value: "with space"))
    }

    func test_parse() {
        do { // No colon
            XCTAssertNil(SearchFilter.parse(filterTerm: "a"))
        }
        
        do { // Too many colons
            XCTAssertNil(SearchFilter.parse(filterTerm: "a:b:c"))
        }

        do { // No valid filter
            XCTAssertNil(SearchFilter.parse(filterTerm: "invalid:true"))
        }
        
        do { // Valid filter
            XCTAssertTrue(SearchFilter.parse(filterTerm: "stars:5") is StarsSearchFilter)
        }
        
    }
    
    func test_separateTermsAndFilters() {
        let output = SearchFilter.split(terms: ["a", "b", "invalid:true", "stars:5"])
        
        XCTAssertEqual(output.terms.sorted(), ["a", "b", "invalid:true"])
        
        XCTAssertEqual(output.filters.count, 1)
        XCTAssertTrue(output.filters[0] is StarsSearchFilter)
    }
    
    // MARK: Filters

    func test_authorFilter() throws {
        let filter = try AuthorSearchFilter(expression: .init(operator: .is,
                                                              value: "sherlouk"))
        XCTAssertEqual(filter.key, .author)
        XCTAssertEqual(filter.predicate, .init(operator: .caseInsensitiveLike,
                                               bindableValue: .value("sherlouk"),
                                               displayValue: "sherlouk"))

        // test view representation
        XCTAssertEqual(filter.viewModel.description, "author is sherlouk")

        // test sql representation
        XCTAssertEqual(renderSQL(filter.leftHandSide), #""repo_owner""#)
        XCTAssertEqual(renderSQL(filter.sqlOperator), "ILIKE")
        XCTAssertEqual(binds(filter.rightHandSide), ["sherlouk"])

        // test error case
        XCTAssertThrowsError(try AuthorSearchFilter(expression: .init(operator: .greaterThan,
                                                                      value: "sherlouk"))) {
            XCTAssertEqual($0 as? SearchFilterError, .unsupportedComparisonMethod)
        }
    }

    func test_keywordFilter() throws {
        let filter = try KeywordSearchFilter(expression: .init(operator: .is,
                                                               value: "cache"))
        XCTAssertEqual(filter.key, .keyword)
        XCTAssertEqual(filter.predicate, .init(operator: .caseInsensitiveLike,
                                               bindableValue: .value("cache"),
                                               displayValue: "cache"))

        // test view representation
        XCTAssertEqual(filter.viewModel.description, "keywords is cache")

        // test sql representation
        XCTAssertEqual(renderSQL(filter.leftHandSide), "$1")
        XCTAssertEqual(binds(filter.leftHandSide), ["cache"])
        XCTAssertEqual(renderSQL(filter.sqlOperator), "ILIKE")
        XCTAssertEqual(renderSQL(filter.rightHandSide), #"ANY("keywords")"#)

        // test error case
        XCTAssertThrowsError(try KeywordSearchFilter(expression: .init(operator: .greaterThan,
                                                                      value: "cache"))) {
            XCTAssertEqual($0 as? SearchFilterError, .unsupportedComparisonMethod)
        }
    }

    func test_lastActivityFilter() throws {
        let filter = try LastActivitySearchFilter(expression: .init(operator: .is,
                                                               value: "1970-01-01"))
        XCTAssertEqual(filter.key, .lastActivity)
        XCTAssertEqual(filter.predicate, .init(operator: .equal,
                                               bindableValue: .value("1970-01-01"),
                                               displayValue: "1 Jan 1970"))

        // test view representation
        XCTAssertEqual(filter.viewModel.description, "last activity is 1 Jan 1970")

        // test sql representation
        XCTAssertEqual(renderSQL(filter.leftHandSide), #""last_activity_at""#)
        XCTAssertEqual(renderSQL(filter.sqlOperator), "=")
        XCTAssertEqual(binds(filter.rightHandSide), ["1970-01-01"])

        // test error case
        XCTAssertThrowsError(try LastActivitySearchFilter(
            expression: .init(operator: .greaterThan, value: "23rd June 2021"))
        ) {
            XCTAssertEqual($0 as? SearchFilterError, .invalidValueType)
        }
    }

    func test_lastCommitFilter() throws {
        let filter = try LastCommitSearchFilter(expression: .init(operator: .is,
                                                               value: "1970-01-01"))
        XCTAssertEqual(filter.key, .lastCommit)
        XCTAssertEqual(filter.predicate, .init(operator: .equal,
                                               bindableValue: .value("1970-01-01"),
                                               displayValue: "1 Jan 1970"))

        // test view representation
        XCTAssertEqual(filter.viewModel.description, "last commit is 1 Jan 1970")

        // test sql representation
        XCTAssertEqual(renderSQL(filter.leftHandSide), #""last_commit_date""#)
        XCTAssertEqual(renderSQL(filter.sqlOperator), "=")
        XCTAssertEqual(binds(filter.rightHandSide), ["1970-01-01"])

        // test error case
        XCTAssertThrowsError(try LastCommitSearchFilter(
            expression: .init(operator: .greaterThan, value: "23rd June 2021"))
        ) {
            XCTAssertEqual($0 as? SearchFilterError, .invalidValueType)
        }
    }

    func test_licenseFilter_compatible() throws {
        let filter = try LicenseSearchFilter(expression: .init(operator: .is,
                                                               value: "compatible"))
        XCTAssertEqual(filter.key, .license)
        XCTAssertEqual(filter.predicate, .init(operator: .in,
                                               bindableValue: .array(["afl-3.0", "apache-2.0", "artistic-2.0", "bsd-2-clause", "bsd-3-clause", "bsd-3-clause-clear", "bsl-1.0", "cc", "cc0-1.0", "cc-by-4.0", "cc-by-sa-4.0", "wtfpl", "ecl-2.0", "epl-1.0", "eupl-1.1", "isc", "ms-pl", "mit", "mpl-2.0", "osl-3.0", "postgresql", "ncsa", "unlicense", "zlib"]),
                                               displayValue: "compatible with the App Store"))

        // test view representation
        XCTAssertEqual(filter.viewModel.description, "license is compatible with the App Store")

        // test sql representation
        XCTAssertEqual(renderSQL(filter.leftHandSide), #""license""#)
        XCTAssertEqual(renderSQL(filter.sqlOperator), "IN")
        XCTAssertEqual(binds(filter.rightHandSide), ["afl-3.0", "apache-2.0", "artistic-2.0", "bsd-2-clause", "bsd-3-clause", "bsd-3-clause-clear", "bsl-1.0", "cc", "cc0-1.0", "cc-by-4.0", "cc-by-sa-4.0", "wtfpl", "ecl-2.0", "epl-1.0", "eupl-1.1", "isc", "ms-pl", "mit", "mpl-2.0", "osl-3.0", "postgresql", "ncsa", "unlicense", "zlib"])
    }

    func test_licenseFilter_single() throws {
        let filter = try LicenseSearchFilter(expression: .init(operator: .is,
                                                               value: "mit"))
        XCTAssertEqual(filter.key, .license)
        XCTAssertEqual(filter.predicate, .init(operator: .in,
                                               bindableValue: .array(["mit"]),
                                               displayValue: "MIT"))

        // test view representation
        XCTAssertEqual(filter.viewModel.description, "license is MIT")

        // test sql representation
        XCTAssertEqual(renderSQL(filter.leftHandSide), #""license""#)
        XCTAssertEqual(renderSQL(filter.sqlOperator), "IN")
        XCTAssertEqual(binds(filter.rightHandSide), ["mit"])
    }

    func test_licenseFilter_case_insensitive() throws {
        XCTAssertEqual(
            try LicenseSearchFilter(
                expression: .init(operator: .is,
                                  value: "mit")).bindableValue,
            ["mit"]
        )
        XCTAssertEqual(
            try LicenseSearchFilter(
                expression: .init(operator: .is,
                                  value: "MIT")).bindableValue,
            ["mit"]
        )
        XCTAssertEqual(
            try LicenseSearchFilter(
                expression: .init(operator: .is,
                                  value: "Compatible")).bindableValue,
            ["afl-3.0", "apache-2.0", "artistic-2.0", "bsd-2-clause", "bsd-3-clause", "bsd-3-clause-clear", "bsl-1.0", "cc", "cc0-1.0", "cc-by-4.0", "cc-by-sa-4.0", "wtfpl", "ecl-2.0", "epl-1.0", "eupl-1.1", "isc", "ms-pl", "mit", "mpl-2.0", "osl-3.0", "postgresql", "ncsa", "unlicense", "zlib"]
        )
    }

    func test_licenseFilter_incompatible() throws {
        let filter = try LicenseSearchFilter(expression: .init(operator: .is,
                                                               value: "incompatible"))
        XCTAssertEqual(filter.key, .license)
        XCTAssertEqual(filter.predicate, .init(operator: .in,
                                               bindableValue: .array(["agpl-3.0", "gpl", "gpl-2.0", "gpl-3.0", "lgpl", "lgpl-2.1", "lgpl-3.0"]),
                                               displayValue: "incompatible with the App Store"))

        // test view representation
        XCTAssertEqual(filter.viewModel.description, "license is incompatible with the App Store")

        // test sql representation
        XCTAssertEqual(renderSQL(filter.leftHandSide), #""license""#)
        XCTAssertEqual(renderSQL(filter.sqlOperator), "IN")
        XCTAssertEqual(binds(filter.rightHandSide), ["agpl-3.0", "gpl", "gpl-2.0", "gpl-3.0", "lgpl", "lgpl-2.1", "lgpl-3.0"])
    }

    func test_licenseFilter_none() throws {
        let filter = try LicenseSearchFilter(expression: .init(operator: .is,
                                                               value: "none"))
        XCTAssertEqual(filter.key, .license)
        XCTAssertEqual(filter.predicate, .init(operator: .in,
                                               bindableValue: .array(["none"]),
                                               displayValue: "not defined"))

        // test view representation
        XCTAssertEqual(filter.viewModel.description, "license is not defined")

        // test sql representation
        XCTAssertEqual(renderSQL(filter.leftHandSide), #""license""#)
        XCTAssertEqual(renderSQL(filter.sqlOperator), "IN")
        XCTAssertEqual(binds(filter.rightHandSide), ["none"])
    }

    func test_licenseFilter_other() throws {
        let filter = try LicenseSearchFilter(expression: .init(operator: .is,
                                                               value: "other"))
        XCTAssertEqual(filter.key, .license)
        XCTAssertEqual(filter.predicate, .init(operator: .in,
                                               bindableValue: .array(["other"]),
                                               displayValue: "unknown"))

        // test view representation
        XCTAssertEqual(filter.viewModel.description, "license is unknown")

        // test sql representation
        XCTAssertEqual(renderSQL(filter.leftHandSide), #""license""#)
        XCTAssertEqual(renderSQL(filter.sqlOperator), "IN")
        XCTAssertEqual(binds(filter.rightHandSide), ["other"])
    }

    func test_licenseFilter_error() throws {
        // test error case
        XCTAssertThrowsError(try LicenseSearchFilter(
            expression: .init(operator: .greaterThan, value: "mit"))
        ) {
            XCTAssertEqual($0 as? SearchFilterError, .unsupportedComparisonMethod)
        }
    }

    func test_platformFilter_single_value() throws {
        // test single value happy path
        let filter = try PlatformSearchFilter(expression: .init(operator: .is,
                                                                value: "ios"))
        XCTAssertEqual(filter.key, .platform)
        XCTAssertEqual(filter.predicate, .init(operator: .contains,
                                               bindableValue: .value("ios"),
                                               displayValue: "iOS"))

        // test view representation
        XCTAssertEqual(filter.viewModel.description, "platform compatibility is iOS")

        // test sql representation
        XCTAssertEqual(renderSQL(filter.leftHandSide), #""platform_compatibility""#)
        XCTAssertEqual(renderSQL(filter.sqlOperator), "@>")
        XCTAssertEqual(binds(filter.rightHandSide), ["{ios}"])
    }

    func test_platformFilter_case_insensitive() throws {
        XCTAssertEqual(
            try PlatformSearchFilter(expression: .init(operator: .is,
                                                       value: "ios")).bindableValue,
            [.ios]
        )
        XCTAssertEqual(
            try PlatformSearchFilter(expression: .init(operator: .is,
                                                       value: "iOS")).bindableValue,
            [.ios]
        )
    }

    func test_platformFilter_deduplication() throws {
        // test de-duplication and compact-mapping of invalid terms
        XCTAssertEqual(
            try PlatformSearchFilter(expression: .init(operator: .is,
                                                       value: "iOS,macos,MacOS X")).bindableValue,
            [.ios, .macos]
        )
        XCTAssertEqual(
            try PlatformSearchFilter(expression: .init(operator: .is,
                                                       value: "iOS,macos,ios")).bindableValue,
            [.ios, .macos]
        )
    }

    func test_platformFilter_multiple_values() throws {
        // test predicate with multiple values
        do {
            let predicate = try PlatformSearchFilter(
                expression: .init(operator: .is, value: "iOS,macos,ios")).predicate
            XCTAssertEqual(predicate.bindableValue.asPlatforms,
                           [.ios, .macos])
            XCTAssertEqual(predicate.operator, .contains)
        }
        do {
            let predicate = try PlatformSearchFilter(
                expression: .init(operator: .is,
                                  value: "iOS,macos,linux")).predicate
            XCTAssertEqual(predicate.bindableValue.asPlatforms,
                           [.ios, .linux, .macos])
            XCTAssertEqual(predicate.operator, .contains)
        }

        // test view representation with multiple values
        XCTAssertEqual(
            try PlatformSearchFilter(expression: .init(operator: .is,
                                                       value: "iOS,macos,ios"))
                .viewModel.description,
            "platform compatibility is iOS and macOS"
        )
        XCTAssertEqual(
            try PlatformSearchFilter(expression: .init(operator: .is,
                                                       value: "iOS,macos,linux"))
                .viewModel.description,
            "platform compatibility is iOS, Linux, and macOS"
        )
    }

    func test_platformFilter_error() throws {
        // test error cases
        XCTAssertThrowsError(try PlatformSearchFilter(
            expression: .init(operator: .isNot, value: "foo"))
        ) {
            XCTAssertEqual($0 as? SearchFilterError, .unsupportedComparisonMethod)
        }
        for value in ["foo", "", ",", "MacOS X"] {
            XCTAssertThrowsError(try PlatformSearchFilter(
                expression: .init(operator: .is, value: value))
            ) {
                XCTAssertEqual($0 as? SearchFilterError, .invalidValueType, "expected exception for value: \(value)")
            }
        }
    }

    func test_starsFilter() throws {
        let filter = try StarsSearchFilter(expression: .init(operator: .is, value: "1234"))
        XCTAssertEqual(filter.key, .stars)
        XCTAssertEqual(filter.predicate, .init(operator: .equal,
                                               bindableValue: .value("1234"),
                                               displayValue: "1,234"))

        // test view representation
        XCTAssertEqual(filter.viewModel.description, "stars is 1,234")

        // test sql representation
        XCTAssertEqual(renderSQL(filter.leftHandSide), #""stars""#)
        XCTAssertEqual(renderSQL(filter.sqlOperator), "=")
        XCTAssertEqual(binds(filter.rightHandSide), ["1234"])

        // test error case
        XCTAssertThrowsError(try StarsSearchFilter(
            expression: .init(operator: .greaterThan, value: "one"))
        ) {
            XCTAssertEqual($0 as? SearchFilterError, .invalidValueType)
        }
    }

    func test_productTypeFilter_single_value() throws {
        // test single value happy path
        let filter = try ProductTypeSearchFilter(expression: .init(operator: .is,
                                                                value: "executable"))
        XCTAssertEqual(filter.key, .productType)
        XCTAssertEqual(filter.predicate, .init(operator: .contains,
                                               bindableValue: .value("executable"),
                                               displayValue: "Executable"))

        // test view representation
        XCTAssertEqual(filter.viewModel.description, "product type is Executable")

        // test sql representation
        XCTAssertEqual(renderSQL(filter.leftHandSide), #""type""#)
        XCTAssertEqual(renderSQL(filter.sqlOperator), "@>")
        XCTAssertEqual(binds(filter.rightHandSide), ["executable"])
    }

    func test_productTypeFilter_case_insensitive() throws {
        XCTAssertEqual(
            try ProductTypeSearchFilter(expression: .init(operator: .is, value: "plugin")).bindableValue,
            [.plugin]
        )
        XCTAssertEqual(
            try ProductTypeSearchFilter(expression: .init(operator: .is, value: "PluGIN")).bindableValue,
            [.plugin]
        )
    }

    func test_productTypeFilter_error() throws {
        // test error cases
        XCTAssertThrowsError(try ProductTypeSearchFilter(
            expression: .init(operator: .isNot, value: "foo"))
        ) {
            XCTAssertEqual($0 as? SearchFilterError, .unsupportedComparisonMethod)
        }
        for value in ["foo", "", ",", "MacOS X"] {
            XCTAssertThrowsError(try ProductTypeSearchFilter(
                expression: .init(operator: .is, value: value))
            ) {
                XCTAssertEqual($0 as? SearchFilterError, .invalidValueType, "expected exception for value: \(value)")
            }
        }
    }

}


extension SearchFilter.ViewModel: CustomStringConvertible {
    public var description: String {
        "\(key) \(`operator`) \(value)"
    }
}


private extension PlatformSearchFilter {
    var bindableValue: Set<Package.PlatformCompatibility>? {
        guard case let .value(value) = predicate.bindableValue else {
            return nil
        }
        return value as? Set<Package.PlatformCompatibility>
    }
}


private extension ProductTypeSearchFilter {
    var bindableValue: Set<Package.ProductType>? {
        guard case let .value(value) = predicate.bindableValue else {
            return nil
        }
        return value as? Set<Package.ProductType>
    }
}


private extension LicenseSearchFilter {
    var bindableValue: [String]? {
        guard case let .array(value) = predicate.bindableValue else {
            return nil
        }
        return value as? [String]
    }
}


private extension SearchFilterProtocol {
    var key: SearchFilter.Key {
        type(of: self).key
    }
}


extension SearchFilter.Predicate: Equatable {
    public static func == (lhs: SearchFilter.Predicate, rhs: SearchFilter.Predicate) -> Bool {
        lhs.operator == rhs.operator
        && lhs.bindableValue == rhs.bindableValue
        && lhs.displayValue == rhs.displayValue
    }
}


extension SearchFilter.Predicate.BoundValue: Equatable {
    public static func == (lhs: SearchFilter.Predicate.BoundValue, rhs: SearchFilter.Predicate.BoundValue) -> Bool {
        renderSQL(lhs.sqlBind) == renderSQL(rhs.sqlBind)
    }

    var asPlatforms: [Package.PlatformCompatibility]? {
        switch self {
            case .value(let value):
                return (value as? Set<Package.PlatformCompatibility>)?
                    .sorted { $0.rawValue < $1.rawValue }
            case .array:
                return nil
        }
    }

    var asProductTypes: [Package.ProductType]? {
        switch self {
            case .value(let value):
                return (value as? Set<Package.ProductType>)?
                    .sorted { $0.rawValue < $1.rawValue }
            case .array:
                return nil
        }
    }
}


// This renderSQL helper uses a dummy SQLDatabase dialect defined in `TestDatabase`.
// It should only be used in cases where app.db (which is using the PostgresDB dialect)
// is not available and where the exact syntax of SQL details is not relevant.
private func renderSQL(_ query: SQLExpression) -> String {
    var serializer = SQLSerializer(database: TestDatabase())
    query.serialize(to: &serializer)
    return serializer.sql
}
