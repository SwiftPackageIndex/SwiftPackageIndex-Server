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

#warning("rename to SearchFilterProtocol?")
protocol SearchFilter {
    /// The key or selector used to formulate the first part of the search syntax.
    ///
    /// `<key>:<operator?><value>`
    static var key: SearchFilterKey { get }
    
    /// Create an instance of a search filter, using a given string value and comparison operator.
    ///
    /// An error should be thrown if the value cannot be converted to the appropriate type, or if the comparison method is not supported for that filter.
    @available(*, deprecated)
    init(value: String, comparison: SearchFilterComparison) throws
    
    /// Add a SQLKit `where` clause to the "SELECT" expression, using the filter's stored value and provided comparison method for context.
    func `where`(_ builder: SQLPredicateGroupBuilder) -> SQLPredicateGroupBuilder

//    #warning("can we drop this?")
//    @available(*, deprecated)
//    var rawValue: String { get }

    var bindableValue: Encodable { get }
    var displayValue: String { get }
    var `operator`: SearchFilterComparison { get }
}

extension SearchFilter {
    func `where`(_ builder: SQLPredicateGroupBuilder) -> SQLPredicateGroupBuilder {
        builder.where(Self.key.sqlIdentifier,
                      `operator`.binaryOperator,
                      SQLBind(bindableValue))
    }
}

#warning("move to view model source file")
struct SearchFilterViewModel: Equatable, Codable {
    let key: SearchFilterKey
    let comparison: SearchFilterComparison
    let value: String
}

#warning("flip around and turn it into init(filter: SearchFilter) if possible")
extension SearchFilter {
    /// Creates a simple view model representation of this active filter. This is used to pass through to the view for client-side rendering.
    func createViewModel() -> SearchFilterViewModel {
        .init(key: Self.key, comparison: `operator`, value: displayValue)
    }
}


#warning("rename to SearchFilterOperator")
enum SearchFilterComparison: String, Codable, Equatable {
    case greaterThan = ">"
    case greaterThanOrEqual = ">="
    case lessThan = "<"
    case lessThanOrEqual = "<="
    case match
    case negativeMatch = "!"

    init?(searchTerm: String) {
        switch searchTerm {
            case _ where searchTerm.hasPrefix(">="):
                self = .greaterThanOrEqual
            case _ where searchTerm.hasPrefix(">"):
                self = .greaterThan
            case _ where searchTerm.hasPrefix("<="):
                self = .lessThanOrEqual
            case _ where searchTerm.hasPrefix("<"):
                self = .lessThan
            case _ where searchTerm.hasPrefix("!"):
                self = .negativeMatch
            case _ where !searchTerm.isEmpty:
                self = .match
            default:
                return nil
        }
    }

    var parseLength: Int {
        switch self {
            case .greaterThan, .greaterThanOrEqual, .lessThan, .lessThanOrEqual, .negativeMatch:
                return rawValue.count
            case .match:
                return 0
        }
    }

    #warning("rename to sqlOperator")
    var binaryOperator: SQLBinaryOperator {
        switch self {
            case .greaterThan:
                return .greaterThan
            case .greaterThanOrEqual:
                return .greaterThanOrEqual
            case .lessThan:
                return .lessThan
            case .lessThanOrEqual:
                return .lessThanOrEqual
            case .negativeMatch:
                return .notEqual
            case .match:
                return .equal
        }
    }
    
    @available(*, deprecated)
    var userFacingString: String {
        switch self {
        case .match: return "is"
        case .negativeMatch: return "is not"
        case .greaterThan: return "is greater than"
        case .greaterThanOrEqual: return "is greater than or equal to"
        case .lessThan: return "is less than"
        case .lessThanOrEqual: return "is less than or equal to"
        }
    }
}

enum SearchFilterError: Error {
    case invalidValueType
    case unsupportedComparisonMethod
}
