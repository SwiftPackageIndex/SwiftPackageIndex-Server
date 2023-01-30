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


protocol SearchFilterProtocol {
    /// The key or selector used to formulate the first part of the search syntax.
    ///
    /// `<key>:<operator?><value>`
    static var key: SearchFilter.Key { get }

    /// Create an instance of a search filter from a parsed search filter expression.
    ///
    /// An error should be thrown if the value cannot be converted to the appropriate type, or if the comparison method is not supported for that filter.
    init(expression: SearchFilter.Expression) throws

    /// The search filter predicate, which is derived from the search filter expression.
    ///
    /// The search filter expression represents the tokanized search expression provided by the user. The search
    /// filter predicate is the search expression as interpreted by a particular filter.
    ///
    /// For instance, a search expression's `.is` operator can be transformed into an `.caseInsensitiveLike`
    /// or an `.equal` depending on the semantics of the particular filter.
    var predicate: SearchFilter.Predicate { get }

    /// The left-hand-side of the where clause expression. Optional, has default implementation.
    var leftHandSide: SQLExpression { get }

    /// The comparison operator of the where clause expression. Optional, has default implementation.
    var sqlOperator: SQLExpression { get }

    /// The right-hand-side of the where clause expression. Optional, has default implementation.
    var rightHandSide: SQLExpression { get }
}


extension SearchFilterProtocol {
    var leftHandSide: SQLExpression { Self.key.sqlIdentifier }
    var sqlOperator: SQLExpression { predicate.sqlOperator }
    var rightHandSide: SQLExpression { predicate.sqlBind }
}
