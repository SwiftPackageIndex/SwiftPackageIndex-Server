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

import SnapshotTesting
import SQLKit
import Testing


extension AllTests.SearchFilterTests {

    @Test func SearchFilterKey_searchFilter() throws {
        // Ensure all `SearchFilter.Key`s are wired correctly to their
        // `SearchFilterProtocol.Type`s (by roundtripping through the key values)
        #expect(SearchFilter.Key.allCases
                        .map { $0.searchFilter.key } == [
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

    @Test func Expression_init() throws {
        #expect(SearchFilter.Expression(predicate: ">5") == .init(operator: .greaterThan, value: "5"))
        #expect(SearchFilter.Expression(predicate: ">=5") == .init(operator: .greaterThanOrEqual, value: "5"))
        #expect(SearchFilter.Expression(predicate: "<5") == .init(operator: .lessThan, value: "5"))
        #expect(SearchFilter.Expression(predicate: "<=5") == .init(operator: .lessThanOrEqual, value: "5"))
        #expect(SearchFilter.Expression(predicate: "!5") == .init(operator: .isNot, value: "5"))
        #expect(SearchFilter.Expression(predicate: "5") == .init(operator: .is, value: "5"))
        #expect(SearchFilter.Expression(predicate: "") == nil)
        #expect(SearchFilter.Expression(predicate: "!with space") == .init(operator: .isNot, value: "with space"))
    }

    @Test func parse() {
        do { // No colon
            #expect(SearchFilter.parse(filterTerm: "a") == nil)
        }

        do { // Too many colons
            #expect(SearchFilter.parse(filterTerm: "a:b:c") == nil)
        }

        do { // No valid filter
            #expect(SearchFilter.parse(filterTerm: "invalid:true") == nil)
        }

        do { // Valid filter
            #expect(SearchFilter.parse(filterTerm: "stars:5") is StarsSearchFilter)
        }

    }

    @Test func separateTermsAndFilters() {
        let output = SearchFilter.split(terms: ["a", "b", "invalid:true", "stars:5"])

        #expect(output.terms.sorted() == ["a", "b", "invalid:true"])

        #expect(output.filters.count == 1)
        #expect(output.filters[0] is StarsSearchFilter)
    }

    // MARK: Filters

    @Test func authorFilter() async throws {
        try await withApp { app in
            let filter = try AuthorSearchFilter(expression: .init(operator: .is,
                                                                  value: "sherlouk"))
            #expect(filter.key == .author)
            #expect(filter.predicate == .init(operator: .caseInsensitiveLike,
                                              bindableValue: .value("sherlouk"),
                                              displayValue: "sherlouk"))

            // test view representation
            #expect(filter.viewModel.description == "author is sherlouk")

            // test sql representation
            #expect(app.db.renderSQL(filter.leftHandSide) == #""repo_owner""#)
            #expect(app.db.renderSQL(filter.sqlOperator) == "ILIKE")
            #expect(app.db.binds(filter.rightHandSide) == ["sherlouk"])

            // test error case
            #expect {
                try AuthorSearchFilter(expression: .init(operator: .greaterThan, value: "sherlouk"))
            } throws: {
                $0 as? SearchFilterError == .unsupportedComparisonMethod
            }
        }
    }

    @Test func keywordFilter() async throws {
        try await withApp { app in
            let filter = try KeywordSearchFilter(expression: .init(operator: .is,
                                                                   value: "cache"))
            #expect(filter.key == .keyword)
            #expect(filter.predicate == .init(operator: .caseInsensitiveLike,
                                              bindableValue: .value("cache"),
                                              displayValue: "cache"))

            // test view representation
            #expect(filter.viewModel.description == "keywords is cache")

            // test sql representation
            #expect(app.db.renderSQL(filter.leftHandSide) == "$1")
            #expect(app.db.binds(filter.leftHandSide) == ["cache"])
            #expect(app.db.renderSQL(filter.sqlOperator) == "ILIKE")
            #expect(app.db.renderSQL(filter.rightHandSide) == #"ANY("keywords")"#)

            // test error case
            #expect {
                try KeywordSearchFilter(expression: .init(operator: .greaterThan, value: "cache"))
            } throws: {
                $0 as? SearchFilterError == .unsupportedComparisonMethod
            }
        }
    }

    @Test func lastActivityFilter() async throws {
        try await withApp { app in
            let filter = try LastActivitySearchFilter(expression: .init(operator: .is,
                                                                        value: "1970-01-01"))
            #expect(filter.key == .lastActivity)
            #expect(filter.predicate == .init(operator: .equal,
                                              bindableValue: .value("1970-01-01"),
                                              displayValue: "1 Jan 1970"))

            // test view representation
            #expect(filter.viewModel.description == "last activity is 1 Jan 1970")

            // test sql representation
            #expect(app.db.renderSQL(filter.leftHandSide) == #""last_activity_at""#)
            #expect(app.db.renderSQL(filter.sqlOperator) == "=")
            #expect(app.db.binds(filter.rightHandSide) == ["1970-01-01"])

            // test error case
            #expect {
                try LastActivitySearchFilter(expression: .init(operator: .greaterThan, value: "23rd June 2021"))
            } throws: {
                $0 as? SearchFilterError == .invalidValueType
            }
        }
    }

    @Test func lastCommitFilter() async throws {
        try await withApp { app in
            let filter = try LastCommitSearchFilter(expression: .init(operator: .is,
                                                                      value: "1970-01-01"))
            #expect(filter.key == .lastCommit)
            #expect(filter.predicate == .init(operator: .equal,
                                              bindableValue: .value("1970-01-01"),
                                              displayValue: "1 Jan 1970"))

            // test view representation
            #expect(filter.viewModel.description == "last commit is 1 Jan 1970")

            // test sql representation
            #expect(app.db.renderSQL(filter.leftHandSide) == #""last_commit_date""#)
            #expect(app.db.renderSQL(filter.sqlOperator) == "=")
            #expect(app.db.binds(filter.rightHandSide) == ["1970-01-01"])

            // test error case
            #expect {
                try LastCommitSearchFilter(expression: .init(operator: .greaterThan, value: "23rd June 2021"))
            } throws: {
                $0 as? SearchFilterError == .invalidValueType
            }
        }
    }

    @Test func licenseFilter_compatible() async throws {
        try await withApp { app in
            let filter = try LicenseSearchFilter(expression: .init(operator: .is,
                                                                   value: "compatible"))
            #expect(filter.key == .license)
            #expect(filter.predicate == .init(operator: .in,
                                              bindableValue: .array(["afl-3.0", "apache-2.0", "artistic-2.0", "bsd-2-clause", "bsd-3-clause", "bsd-3-clause-clear", "bsl-1.0", "cc", "cc0-1.0", "cc-by-4.0", "cc-by-sa-4.0", "wtfpl", "ecl-2.0", "epl-1.0", "eupl-1.1", "isc", "ms-pl", "mit", "mpl-2.0", "osl-3.0", "postgresql", "ncsa", "unlicense", "zlib"]),
                                              displayValue: "compatible with the App Store"))

            // test view representation
            #expect(filter.viewModel.description == "license is compatible with the App Store")

            // test sql representation
            #expect(app.db.renderSQL(filter.leftHandSide) == #""license""#)
            #expect(app.db.renderSQL(filter.sqlOperator) == "IN")
            #expect(app.db.binds(filter.rightHandSide) == ["afl-3.0", "apache-2.0", "artistic-2.0", "bsd-2-clause", "bsd-3-clause", "bsd-3-clause-clear", "bsl-1.0", "cc", "cc0-1.0", "cc-by-4.0", "cc-by-sa-4.0", "wtfpl", "ecl-2.0", "epl-1.0", "eupl-1.1", "isc", "ms-pl", "mit", "mpl-2.0", "osl-3.0", "postgresql", "ncsa", "unlicense", "zlib"])
        }
    }

    @Test func licenseFilter_single() async throws {
        try await withApp { app in
            let filter = try LicenseSearchFilter(expression: .init(operator: .is,
                                                                   value: "mit"))
            #expect(filter.key == .license)
            #expect(filter.predicate == .init(operator: .in,
                                              bindableValue: .array(["mit"]),
                                              displayValue: "MIT"))

            // test view representation
            #expect(filter.viewModel.description == "license is MIT")

            // test sql representation
            #expect(app.db.renderSQL(filter.leftHandSide) == #""license""#)
            #expect(app.db.renderSQL(filter.sqlOperator) == "IN")
            #expect(app.db.binds(filter.rightHandSide) == ["mit"])
        }
    }

    @Test func licenseFilter_case_insensitive() throws {
        #expect(
            try LicenseSearchFilter(
                expression: .init(operator: .is,
                                  value: "mit")).bindableValue == ["mit"]
        )
        #expect(
            try LicenseSearchFilter(
                expression: .init(operator: .is,
                                  value: "MIT")).bindableValue == ["mit"]
        )
        #expect(
            try LicenseSearchFilter(
                expression: .init(operator: .is,
                                  value: "Compatible")).bindableValue == ["afl-3.0", "apache-2.0", "artistic-2.0", "bsd-2-clause", "bsd-3-clause", "bsd-3-clause-clear", "bsl-1.0", "cc", "cc0-1.0", "cc-by-4.0", "cc-by-sa-4.0", "wtfpl", "ecl-2.0", "epl-1.0", "eupl-1.1", "isc", "ms-pl", "mit", "mpl-2.0", "osl-3.0", "postgresql", "ncsa", "unlicense", "zlib"]
        )
    }

    @Test func licenseFilter_incompatible() async throws {
        try await withApp { app in
            let filter = try LicenseSearchFilter(expression: .init(operator: .is,
                                                                   value: "incompatible"))
            #expect(filter.key == .license)
            #expect(filter.predicate == .init(operator: .in,
                                              bindableValue: .array(["agpl-3.0", "gpl", "gpl-2.0", "gpl-3.0", "lgpl", "lgpl-2.1", "lgpl-3.0"]),
                                              displayValue: "incompatible with the App Store"))

            // test view representation
            #expect(filter.viewModel.description == "license is incompatible with the App Store")

            // test sql representation
            #expect(app.db.renderSQL(filter.leftHandSide) == #""license""#)
            #expect(app.db.renderSQL(filter.sqlOperator) == "IN")
            #expect(app.db.binds(filter.rightHandSide) == ["agpl-3.0", "gpl", "gpl-2.0", "gpl-3.0", "lgpl", "lgpl-2.1", "lgpl-3.0"])
        }
    }

    @Test func licenseFilter_none() async throws {
        try await withApp { app in
            let filter = try LicenseSearchFilter(expression: .init(operator: .is, value: "none"))
            #expect(filter.key == .license)
            #expect(filter.predicate == .init(operator: .in,
                                              bindableValue: .array(["none"]),
                                              displayValue: "not defined"))

            // test view representation
            #expect(filter.viewModel.description == "license is not defined")

            // test sql representation
            #expect(app.db.renderSQL(filter.leftHandSide) == #""license""#)
            #expect(app.db.renderSQL(filter.sqlOperator) == "IN")
            #expect(app.db.binds(filter.rightHandSide) == ["none"])
        }
    }

    @Test func licenseFilter_other() async throws {
        try await withApp { app in
            let filter = try LicenseSearchFilter(expression: .init(operator: .is, value: "other"))
            #expect(filter.key == .license)
            #expect(filter.predicate == .init(operator: .in,
                                              bindableValue: .array(["other"]),
                                              displayValue: "unknown"))

            // test view representation
            #expect(filter.viewModel.description == "license is unknown")

            // test sql representation
            #expect(app.db.renderSQL(filter.leftHandSide) == #""license""#)
            #expect(app.db.renderSQL(filter.sqlOperator) == "IN")
            #expect(app.db.binds(filter.rightHandSide) == ["other"])
        }
    }

    @Test func licenseFilter_error() throws {
        #expect {
            try LicenseSearchFilter(expression: .init(operator: .greaterThan, value: "mit"))
        } throws: {
            $0 as? SearchFilterError == .unsupportedComparisonMethod
        }
    }

    @Test func platformFilter_single_value() async throws {
        // test single value happy path
        try await withApp { app in
            let filter = try PlatformSearchFilter(expression: .init(operator: .is,
                                                                    value: "ios"))
            #expect(filter.key == .platform)
            #expect(filter.predicate == .init(operator: .contains,
                                              bindableValue: .value("ios"),
                                              displayValue: "iOS"))

            // test view representation
            #expect(filter.viewModel.description == "platform compatibility is iOS")

            // test sql representation
            #expect(app.db.renderSQL(filter.leftHandSide) == #""platform_compatibility""#)
            #expect(app.db.renderSQL(filter.sqlOperator) == "@>")
            #expect(app.db.binds(filter.rightHandSide) == ["{ios}"])
        }
    }

    @Test func platformFilter_case_insensitive() throws {
        #expect(
            try PlatformSearchFilter(expression: .init(operator: .is,
                                                       value: "ios")).bindableValue == [.iOS]
        )
        #expect(
            try PlatformSearchFilter(expression: .init(operator: .is,
                                                       value: "iOS")).bindableValue == [.iOS]
        )
    }

    @Test func platformFilter_deduplication() throws {
        // test de-duplication and compact-mapping of invalid terms
        #expect(
            try PlatformSearchFilter(expression: .init(operator: .is,
                                                       value: "iOS,macos,MacOS X")).bindableValue == [.iOS, .macOS]
        )
        #expect(
            try PlatformSearchFilter(expression: .init(operator: .is,
                                                       value: "iOS,macos,ios")).bindableValue == [.iOS, .macOS]
        )
    }

    @Test func platformFilter_multiple_values() throws {
        // test predicate with multiple values
        do {
            let predicate = try PlatformSearchFilter(
                expression: .init(operator: .is, value: "iOS,macos,ios")).predicate
            #expect(predicate.bindableValue.asPlatforms == [.iOS, .macOS])
            #expect(predicate.operator == .contains)
        }
        do {
            let predicate = try PlatformSearchFilter(
                expression: .init(operator: .is,
                                  value: "iOS,macos,linux")).predicate
            #expect(predicate.bindableValue.asPlatforms == [.iOS, .linux, .macOS])
            #expect(predicate.operator == .contains)
        }

        // test view representation with multiple values
        #expect(
            try PlatformSearchFilter(expression: .init(operator: .is,
                                                       value: "iOS,macos,ios"))
                .viewModel.description == "platform compatibility is iOS and macOS"
        )
        #expect(
            try PlatformSearchFilter(expression: .init(operator: .is,
                                                       value: "iOS,macos,linux"))
                .viewModel.description == "platform compatibility is iOS, Linux, and macOS"
        )
    }

    @Test func platformFilter_error() throws {
        #expect {
            try PlatformSearchFilter(expression: .init(operator: .isNot, value: "foo"))
        } throws: {
            $0 as? SearchFilterError == .unsupportedComparisonMethod
        }
        for value in ["foo", "", ",", "MacOS X"] {
            #expect("expected exception for value: \(value)") {
                try PlatformSearchFilter(expression: .init(operator: .is, value: value))
            } throws: {
                $0 as? SearchFilterError == .invalidValueType
            }
        }
    }

    @Test func starsFilter() async throws {
        try await withApp { app in
            let filter = try StarsSearchFilter(expression: .init(operator: .is, value: "1234"))
            #expect(filter.key == .stars)
            #expect(filter.predicate == .init(operator: .equal,
                                              bindableValue: .value("1234"),
                                              displayValue: "1,234"))

            // test view representation
            #expect(filter.viewModel.description == "stars is 1,234")

            // test sql representation
            #expect(app.db.renderSQL(filter.leftHandSide) == #""stars""#)
            #expect(app.db.renderSQL(filter.sqlOperator) == "=")
            #expect(app.db.binds(filter.rightHandSide) == ["1234"])

            // test error case
            #expect {
                try StarsSearchFilter(expression: .init(operator: .greaterThan, value: "one"))
            } throws: {
                $0 as? SearchFilterError == .invalidValueType
            }
        }
    }

    @Test func productTypeFilter() async throws {
        try await withApp { app in
            // test single value happy path
            let filter = try ProductTypeSearchFilter(expression: .init(operator: .is,
                                                                       value: "executable"))
            #expect(filter.key == .productType)
            #expect(filter.predicate == .init(operator: .contains,
                                              bindableValue: .value("executable"),
                                              displayValue: "Executable"))

            // test view representation
            #expect(filter.viewModel.description == "Package products contain an Executable")

            // test sql representation
            #expect(app.db.renderSQL(filter.leftHandSide) == #""product_types""#)
            #expect(app.db.renderSQL(filter.sqlOperator) == "@>")
            #expect(app.db.binds(filter.rightHandSide) == ["{executable}"])
        }
    }

    @Test func productTypeFilter_macro() async throws {
        try await withApp { app in
            // Test "virtual" macro product filter
            let filter = try ProductTypeSearchFilter(expression: .init(operator: .is, value: "macro"))
            #expect(filter.key == .productType)
            #expect(filter.predicate == .init(operator: .contains,
                                              bindableValue: .value("macro"),
                                              displayValue: "Macro"))

            // test view representation
            #expect(filter.viewModel.description == "Package products contain a Macro")

            // test sql representation
            #expect(app.db.renderSQL(filter.leftHandSide) == #""product_types""#)
            #expect(app.db.renderSQL(filter.sqlOperator) == "@>")
            #expect(app.db.binds(filter.rightHandSide) == ["{macro}"])
        }
    }

    @Test func productTypeFilter_spelling() throws {
        let expectedDisplayValues = [
            ProductTypeSearchFilter.ProductType.executable: "Package products contain an Executable",
            ProductTypeSearchFilter.ProductType.plugin: "Package products contain a Plugin",
            ProductTypeSearchFilter.ProductType.library: "Package products contain a Library",
            ProductTypeSearchFilter.ProductType.macro: "Package products contain a Macro"
        ]

        for type in ProductTypeSearchFilter.ProductType.allCases {
            let filter = try ProductTypeSearchFilter(expression: .init(operator: .is, value: type.rawValue))
            #expect(filter.viewModel.description == expectedDisplayValues[type])
        }
    }

    @Test func productTypeFilter_error() async throws {
        #expect {
            try ProductTypeSearchFilter(expression: .init(operator: .isNot, value: "foo"))
        } throws: {
            $0 as? SearchFilterError == .unsupportedComparisonMethod
        }
        for value in ["foo", "", ",", "MacOS X"] {
            #expect("expected exception for value: \(value)") {
                try ProductTypeSearchFilter(expression: .init(operator: .is, value: value))
            } throws: {
                $0 as? SearchFilterError == .invalidValueType
            }
        }
    }

}


extension App.SearchFilter.ViewModel: Swift.CustomStringConvertible {
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


extension App.SearchFilter.Predicate: Swift.Equatable {
    public static func == (lhs: SearchFilter.Predicate, rhs: SearchFilter.Predicate) -> Bool {
        lhs.operator == rhs.operator
        && lhs.bindableValue == rhs.bindableValue
        && lhs.displayValue == rhs.displayValue
    }
}


extension App.SearchFilter.Predicate.BoundValue: Swift.Equatable {
    public static func == (lhs: SearchFilter.Predicate.BoundValue, rhs: SearchFilter.Predicate.BoundValue) -> Bool {
        renderGenericSQL(lhs.sqlBind) == renderGenericSQL(rhs.sqlBind)
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
}


// This renderSQL helper uses a dummy SQLDatabase dialect defined in `TestDatabase`.
// It should only be used in cases where app.db (which is using the PostgresDB dialect)
// is not available and where the exact syntax of SQL details is not relevant.
private func renderGenericSQL(_ query: SQLExpression) -> String {
    var serializer = SQLSerializer(database: TestDatabase())
    query.serialize(to: &serializer)
    return serializer.sql
}
