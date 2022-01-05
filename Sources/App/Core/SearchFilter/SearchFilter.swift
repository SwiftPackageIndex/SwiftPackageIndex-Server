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
    init(value: String, comparison: SearchFilterComparison) throws

    var sqlIdentifier: SQLIdentifier { get }

    // required
    var bindableValue: Encodable { get }
    var displayValue: String { get }
    var operatorDescription: String { get }
    var sqlOperator: SQLExpression { get }
}

extension SearchFilter {
    var sqlIdentifier: SQLIdentifier { Self.key.sqlIdentifier }
}


#warning("move to view model source file")
struct SearchFilterViewModel: Equatable, Codable {
    var key: String
    var `operator`: String
    var value: String
}


extension SearchFilter {
    /// Creates a simple view model representation of this active filter. This is used to pass through to the view for client-side rendering.
    var viewModel: SearchFilterViewModel {
        .init(key: Self.key.description, operator: operatorDescription, value: displayValue)
    }
}


#warning("rename to SearchFilterOperator")
enum SearchFilterComparison: Codable, Equatable {
    case greaterThan
    case greaterThanOrEqual
    case lessThan
    case lessThanOrEqual
    case match
    case negativeMatch

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
            case .match:
                return 0
            case .negativeMatch:
                return 1
            case .greaterThan, .lessThan:
                return 1
            case .greaterThanOrEqual, .lessThanOrEqual:
                return 2
        }
    }

    var defaultSqlOperator: SQLBinaryOperator {
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
}

extension SearchFilterComparison: CustomStringConvertible {
    var description: String {
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
