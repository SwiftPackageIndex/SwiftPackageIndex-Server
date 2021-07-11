import Foundation
import SQLKit
import Vapor

protocol SearchFilter {
    // <Key>:<Op?><Value>
    static var key: String { get }
    
    init(value: String, comparison: SearchFilterComparison) throws
    func query(_ builder: SQLPredicateGroupBuilder) -> SQLPredicateGroupBuilder
}

struct SearchFilterParser {
    
    static var allSearchFilters: [SearchFilter.Type] = [
        StarsSearchFilter.self,
        LicenseSearchFilter.self,
        UpdatedSearchFilter.self,
    ]
    
    func separate(terms: [String]) -> (terms: [String], filters: [SearchFilter]) {
        terms.reduce(into: (terms: [], filters: [])) { builder, term in
            if let filter = parse(term: term) {
                builder.filters.append(filter)
            } else {
                builder.terms.append(term)
            }
        }
    }
    
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
