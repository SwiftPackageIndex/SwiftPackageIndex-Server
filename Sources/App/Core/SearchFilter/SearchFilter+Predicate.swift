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

import SQLKit


extension SearchFilter {

    /// A `Predicate` describes the search filter operation after parsing and association with
    /// a particular search filter. It can generate its SQL and user facing representation.
    ///
    /// See Also: `SearchFilter.Expression`
    struct Predicate {
        /// The predicate operator, which encapsulates both the SQL and user facing representation
        var `operator`: PredicateOperator

        /// The value of the filter expression in a format that can be bound in an SQL expression.
        var bindableValue: BoundValue

        /// The value of the filter expression for user facing display.
        var displayValue: String
    }
}


extension SearchFilter.Predicate {

    /// `BoundValue` is a wrapper around a bindable value. Its purpose is to allow
    /// creating a different `SQLBind` depending on whether the bindable value is
    /// and array or not.
    enum BoundValue {
        case value(Encodable)
        case array([Encodable])

        var sqlBind: SQLExpression {
            switch self {
                case .value(let value):
                    return SQLBind(value)
                case .array(let items):
                    return SQLBind.group(items)
            }
        }
    }

    var sqlOperator: SQLExpression { `operator`.sqlOperator }
    var sqlBind: SQLExpression { bindableValue.sqlBind }
}


extension SearchFilter {

    /// The predicate operator encapsulates the SQL and user facing representation of the search filter operator.
    ///
    /// It is derived from the `ExpressionOperator` which represents the operator as provided in the search
    /// filter expression by the user. These two operators are distinct, because users can provide search filter
    /// expressions in a shorthand that gets expanded to SQL operators on a per filter type basis.
    enum PredicateOperator: Codable, Equatable {
        case caseInsensitiveLike
        case notCaseInsensitiveLike
        case contains
        case equal
        case notEqual
        case greaterThan
        case greaterThanOrEqual
        case `in`
        case notIn
        case lessThan
        case lessThanOrEqual

        var sqlOperator: SQLExpression {
            switch self {
                case .caseInsensitiveLike:
                    return SQLRaw("ILIKE")
                case .notCaseInsensitiveLike:
                    return SQLRaw("NOT ILIKE")
                case .contains:
                    return SQLRaw("@>")
                case .equal:
                    return SQLBinaryOperator.equal
                case .notEqual:
                    return SQLBinaryOperator.notEqual
                case .greaterThan:
                    return SQLBinaryOperator.greaterThan
                case .greaterThanOrEqual:
                    return SQLBinaryOperator.greaterThanOrEqual
                case .in:
                    return SQLBinaryOperator.in
                case .notIn:
                    return SQLBinaryOperator.notIn
                case .lessThan:
                    return SQLBinaryOperator.lessThan
                case .lessThanOrEqual:
                    return SQLBinaryOperator.lessThanOrEqual
            }
        }

        var displayString: String {
            switch self {
                case .caseInsensitiveLike, .contains, .equal, .in:
                    return "is"
                case .notCaseInsensitiveLike, .notEqual, .notIn:
                    return "is not"
                case .greaterThan:
                    return "is greater than"
                case .greaterThanOrEqual:
                    return "is greater than or equal to"
                case .lessThan:
                    return "is less than"
                case .lessThanOrEqual:
                    return "is less than or equal to"
            }
        }

    }

}
