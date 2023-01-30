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


extension SearchFilter {

    /// An `Expression` represents the search filter expression as provided by the
    /// user. It is later transformed into a `SearchFilter.Predicate` by particular
    /// search filters based on their semantic interpretation of the expression's operator.
    ///
    /// For instance, `.is` in `Expression` can translate to `.caseInsensitiveLike`
    /// or `.contains` in `SearchFilter.Predicate` depending on which filter
    /// is being selected.
    struct Expression: Equatable {
        var `operator`: ExpressionOperator
        var value: String

        init?(predicate: String) {
            switch predicate {
                case _ where predicate.hasPrefix(">="):
                    self.operator = .greaterThanOrEqual
                case _ where predicate.hasPrefix(">"):
                    self.operator = .greaterThan
                case _ where predicate.hasPrefix("<="):
                    self.operator = .lessThanOrEqual
                case _ where predicate.hasPrefix("<"):
                    self.operator = .lessThan
                case _ where predicate.hasPrefix("!"):
                    self.operator = .isNot
                case _ where !predicate.isEmpty:
                    self.operator = .is
                default:
                    return nil
            }
            self.value = String(predicate.dropFirst(self.operator.parseLength))
            guard !self.value.isEmpty else { return nil }
        }

#if DEBUG
        // This initializer is exposed purely to create instances for testing
        init(operator: ExpressionOperator, value: String) {
            self.operator = `operator`
            self.value = value
        }
#endif
    }
}

extension SearchFilter {
    enum ExpressionOperator: String, Equatable {
        case greaterThan
        case greaterThanOrEqual
        case `is`
        case isNot
        case lessThan
        case lessThanOrEqual

        var parseLength: Int {
            switch self {
                case .is:
                    return 0
                case .isNot:
                    return 1
                case .greaterThan, .lessThan:
                    return 1
                case .greaterThanOrEqual, .lessThanOrEqual:
                    return 2
            }
        }

        var defaultPredicateOperator: PredicateOperator {
            switch self {
                case .greaterThan:
                    return .greaterThan
                case .greaterThanOrEqual:
                    return .greaterThanOrEqual
                case .is:
                    return .equal
                case .isNot:
                    return .notEqual
                case .lessThan:
                    return .lessThan
                case .lessThanOrEqual:
                    return .lessThanOrEqual
            }
        }
    }
}
