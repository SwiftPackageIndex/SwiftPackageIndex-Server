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

import SQLKit


/// Filters by ensuring the keywords of the package contain the provided keyword.
///
/// Examples:
/// ```
/// keyword:apple  - The package keywords contain 'apple'
/// keyword:!apple - The package keywords do not contain 'apple'
/// ```
struct KeywordSearchFilter: SearchFilterProtocol {
    static var key: SearchFilter.Key = .keyword

    var predicate: SearchFilter.Predicate

    init(expression: SearchFilter.Expression) throws {
        guard [.is, .isNot].contains(expression.operator) else {
            throw SearchFilterError.unsupportedComparisonMethod
        }

        self.predicate = .init(
            operator: (expression.operator == .is) ?
                .caseInsensitiveLike : .notCaseInsensitiveLike,
            bindableValue: .value(expression.value),
            displayValue: expression.value
        )
    }

    var leftHandSide: SQLExpression {
        predicate.sqlBind
    }

    var rightHandSide: SQLExpression {
        any(Search.keywords)
    }
}
