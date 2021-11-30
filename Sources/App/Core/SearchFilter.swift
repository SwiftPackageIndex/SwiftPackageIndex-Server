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

import Foundation
import SQLKit
import Vapor

protocol SearchFilter {
    /// The key or selector used to formulate the first part of the search syntax.
    ///
    /// `<key>:<operator?><value>`
    static var key: String { get }
    
    /// Create an instance of a search filter, using a given string value and comparison operator.
    ///
    /// An error should be thrown if the value cannot be converted to the appropriate type, or if the comparison method is not supported for that filter.
    init(value: String, comparison: SearchFilterComparison) throws
    
    /// Add a SQLKit `where` clause to the "SELECT" expression, using the filter's stored value and provided comparison method for context.
    func `where`(_ builder: SQLPredicateGroupBuilder) -> SQLPredicateGroupBuilder
    
    /// Creates a simple view model representation of this active filter. This is used to pass through to the view for client-side rendering.
    func createViewModel() -> SearchFilterViewModel
}

struct SearchFilterViewModel: Equatable, Codable {
    let key: String
    let comparison: SearchFilterComparison
    let value: String
}

struct SearchFilterParser {
    
    /// A list of all currently supported search filters.
    static var allSearchFilters: [SearchFilter.Type] = [
        StarsSearchFilter.self,
        LicenseSearchFilter.self,
        LastCommitSearchFilter.self,
    ]
    
    /// Separates search terms from filter syntax.
    ///
    /// A "filter syntax" is a part of the user input which is a set of instructions to the search controller to filter the results by. "Search terms" is anything which is not
    /// a valid filter syntax.
    ///
    /// In this example: `["test", "stars:>500"]` - `"test"` is a search term, and `"stars:>500"` is filter syntax (instructing the search controller to
    /// only return results with more than 500 stars.)
    func split(terms: [String]) -> (terms: [String], filters: [SearchFilter]) {
        return terms.reduce(into: (terms: [], filters: [])) { builder, term in
            if let filter = parse(term: term) {
                builder.filters.append(filter)
            } else {
                builder.terms.append(term)
            }
        }
    }
    
    /// Attempts to identify the appropriate `SearchFilter` for the provided term. If it does not match our filter syntax, then this will return `nil` and it should
    /// be treated as a search term.
    func parse(term: String, allFilters: [SearchFilter.Type] = SearchFilterParser.allSearchFilters) -> SearchFilter? {
        let components = term
            .components(separatedBy: ":")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard components.count == 2 else {
            return nil
        }
        
        // Operator
        let filterComparison: SearchFilterComparison = {
            let comparisonOperator = String(components[1].prefix(1))
            switch comparisonOperator {
                case ">":
                    return .greaterThan
                case "<":
                    return .lessThan
                case "!":
                    return .negativeMatch
                default:
                    return .match
            }
        }()
        
        // Value
        let stringValue = filterComparison == .match ? components[1] : String(components[1].dropFirst())
        guard !stringValue.isEmpty else { return nil }
        
        // Filter
        return try? allFilters
            .first(where: { $0.key == components[0] })?
            .init(value: stringValue, comparison: filterComparison)
    }
    
}

enum SearchFilterComparison: String, Codable, Equatable {
    case match
    case negativeMatch
    case greaterThan
    case lessThan
    
    func binaryOperator(isSet: Bool = false) -> SQLBinaryOperator {
        switch self {
            case .greaterThan:
                return .greaterThan
            case .lessThan:
                return .lessThan
            case .negativeMatch:
                return isSet ? .notIn : .notEqual
            case .match:
                return isSet ? .in : .equal
        }
    }
    
    var userFacingString: String {
        switch self {
        case .match: return "matches"
        case .negativeMatch: return "does not match"
        case .greaterThan: return "is greater than"
        case .lessThan: return "is less than"
        }
    }
}

enum SearchFilterError: Error {
    case invalidValueType
    case unsupportedComparisonMethod
}

// MARK: - Filters



// MARK: Stars

/// Filters by the number of stars the package has.
///
/// Examples:
/// ```
/// stars:5  - Exactly 5 stars
/// stars:>5 - Any number of stars more than 5
/// stars:<5 - Any number of stars less than 5
/// stars:!5 - Any number of stars except 5
/// ```
struct StarsSearchFilter: SearchFilter {
    static var key: String = "stars"
    
    var comparison: SearchFilterComparison
    var value: Int
    
    init(value: String, comparison: SearchFilterComparison) throws {
        guard let intValue = Int(value) else {
            throw SearchFilterError.invalidValueType
        }
        
        self.comparison = comparison
        self.value = intValue
    }
    
    func `where`(_ builder: SQLPredicateGroupBuilder) -> SQLPredicateGroupBuilder {
        builder.where(
            SQLIdentifier("stars"),
            comparison.binaryOperator(),
            value
        )
    }
    
    func createViewModel() -> SearchFilterViewModel {
        .init(
            key: "stars",
            comparison: comparison,
            value: NumberFormatter.starsFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
        )
    }
}

// MARK: License

/// Filters by the license of the package.
///
/// Examples:
/// ```
/// license:compatible   - The license is compatible with the app store
/// license:!compatible - The license is unknown, none is provided, or the one provided is not compatible with the app store
/// license:mit - The package specifically uses the MIT license (any can be used)
/// ```
struct LicenseSearchFilter: SearchFilter {
    enum FilterType: Equatable {
        case appStoreCompatible
        case license(License)
        
        init?(rawValue: String) {
            if rawValue == "compatible" {
                self = .appStoreCompatible
            } else if let license = License(rawValue: rawValue) {
                self = .license(license)
            } else {
                return nil
            }
        }
    }
    
    static var key: String = "license"
    
    let comparison: SearchFilterComparison
    let filterType: FilterType
    
    init(value: String, comparison: SearchFilterComparison) throws {
        guard let filterType = FilterType(rawValue: value) else {
            throw SearchFilterError.invalidValueType
        }
        
        guard [.match, .negativeMatch].contains(comparison) else {
            throw SearchFilterError.unsupportedComparisonMethod
        }
        
        self.comparison = comparison
        self.filterType = filterType
    }
    
    func `where`(_ builder: SQLPredicateGroupBuilder) -> SQLPredicateGroupBuilder {
        switch filterType {
            case .appStoreCompatible:
                return builder.where(
                    SQLIdentifier("license"),
                    comparison.binaryOperator(isSet: true),
                    License.withKind { $0 == .compatibleWithAppStore }
                )
                
            case .license(let license):
                return builder.where(
                    SQLIdentifier("license"),
                    comparison.binaryOperator(isSet: false),
                    license.rawValue
                )
        }
    }
    
    func createViewModel() -> SearchFilterViewModel {
        switch filterType {
        case .appStoreCompatible:
            return .init(key: Self.key, comparison: comparison, value: "App Store compatible")
        case .license(let license):
            return .init(key: Self.key, comparison: comparison, value: license.shortName)
        }
    }
}

// MARK: Last Commit Date

/// Filters by the date in which the package's main branch was last updated.
///
/// Dates must be provided in the `YYYY-MM-DD` format.
///
/// Examples:
/// ```
/// last_commit:2020-07-01  - Last commit made on exactly July 1st 2020
/// last_commit:!2020-07-01 - Last commit made on any day other than July 1st 2020
/// last_commit:>2020-07-01 - Last commit made on any day more recent than July 1st 2020
/// last_commit:<2020-07-01 - Last commit made on any day older than July 1st 2020
/// ```
struct LastCommitSearchFilter: SearchFilter {
    static var parseDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        return formatter
    }()
    
    static var viewDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        return formatter
    }()
    
    static var key: String = "last_commit"
    
    let comparison: SearchFilterComparison
    let date: Date
    let value: String
    
    init(value: String, comparison: SearchFilterComparison) throws {
        guard let date = Self.parseDateFormatter.date(from: value) else {
            throw SearchFilterError.invalidValueType
        }
        
        self.value = value
        self.comparison = comparison
        self.date = date
    }
    
    func `where`(_ builder: SQLPredicateGroupBuilder) -> SQLPredicateGroupBuilder {
        builder.where(
            SQLIdentifier("last_commit_date"),
            comparison.binaryOperator(),
            date
        )
    }
    
    func createViewModel() -> SearchFilterViewModel {
        .init(
            key: "last commit",
            comparison: comparison,
            value: Self.viewDateFormatter.string(from: date)
        )
    }
}
