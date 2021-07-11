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
    func query(_ builder: SQLPredicateGroupBuilder) -> SQLPredicateGroupBuilder
}

struct SearchFilterParser {
    
    /// A list of all currently supported search filters.
    static var allSearchFilters: [SearchFilter.Type] = [
        StarsSearchFilter.self,
        LicenseSearchFilter.self,
        UpdatedSearchFilter.self,
    ]
    
    
    /// Separates search terms from filter syntax.
    ///
    /// A "filter syntax" is a part of the user input which is a set of instructions to the search controller to filter the results by. "Search terms" is anything which is not
    /// a valid filter syntax.
    ///
    /// In this example: `["test", "stars:>500"]` - `"test"` is a search term, and `"stars:>500"` is filter syntax (instructing the search controller to
    /// only return results with more than 500 stars.)
    func separate(terms: [String]) -> (terms: [String], filters: [SearchFilter]) {
        terms.reduce(into: (terms: [], filters: [])) { builder, term in
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
            case ">": return .greaterThan
            case "<": return .lessThan
            case "!": return .negativeMatch
            default:  return .match
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

enum SearchFilterComparison: Equatable {
    case match
    case negativeMatch
    case greaterThan
    case lessThan
    
    func binaryOperator(isSet: Bool = false) -> SQLBinaryOperator {
        switch self {
        case .greaterThan: return .greaterThan
        case .lessThan: return .lessThan
        case .negativeMatch: return isSet ? .notIn : .notEqual
        case .match: return isSet ? .in : .equal
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
    
    func query(_ builder: SQLPredicateGroupBuilder) -> SQLPredicateGroupBuilder {
        builder.where(
            SQLIdentifier("stars"),
            comparison.binaryOperator(),
            value
        )
    }
}

// MARK: License

/// Filters by the license of the package.
///
/// Examples:
/// ```
/// license:compatible   - The license is compatible with the app store
/// license:incompatible - The license is unknown, none is provided, or the one provided is not compatible with the app store
/// ```
struct LicenseSearchFilter: SearchFilter {
    enum FilterType: String, Equatable {
        case compatible
        case incompatible
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
    
    func query(_ builder: SQLPredicateGroupBuilder) -> SQLPredicateGroupBuilder {
        switch filterType {
        case .compatible:
            return builder.where(
                SQLIdentifier("license"),
                comparison.binaryOperator(isSet: true),
                License.withKind { $0 == .compatibleWithAppStore }
            )
            
        case .incompatible:
            return builder.where(
                SQLIdentifier("license"),
                comparison.binaryOperator(isSet: true),
                License.withKind { $0 != .compatibleWithAppStore }
            )
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
/// updated:2020-07-01  - Updated on exactly July 1st 2020
/// updated:!2020-07-01 - Updated on any day other than July 1st 2020
/// updated:>2020-07-01 - Updated on any day more recent than July 1st 2020
/// updated:<2020-07-01 - Updated on any day older than July 1st 2020
/// ```
struct UpdatedSearchFilter: SearchFilter {
    static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        return formatter
    }()
    
    static var key: String = "updated"
    
    let comparison: SearchFilterComparison
    let date: Date
    
    init(value: String, comparison: SearchFilterComparison) throws {
        guard let date = Self.dateFormatter.date(from: value) else {
            throw SearchFilterError.invalidValueType
        }
        
        self.comparison = comparison
        self.date = date
    }
    
    func query(_ builder: SQLPredicateGroupBuilder) -> SQLPredicateGroupBuilder {
        builder.where(
            SQLIdentifier("last_commit_date"),
            comparison.binaryOperator(),
            date
        )
    }
}
