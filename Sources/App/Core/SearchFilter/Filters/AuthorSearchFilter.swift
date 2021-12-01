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

/// Filters by ensuring the author of the package is the provided entity.
///
/// Examples:
/// ```
/// author:apple  - The author of the package is 'apple'
/// author:!apple - The author of the package is not 'apple'
/// ```
struct AuthorSearchFilter: SearchFilter {
    static var key: String = "author"
    
    var comparison: SearchFilterComparison
    var value: String
    
    init(value: String, comparison: SearchFilterComparison) throws {
        guard [.match, .negativeMatch].contains(comparison) else {
            throw SearchFilterError.unsupportedComparisonMethod
        }
        
        self.comparison = comparison
        self.value = value
    }
    
    func `where`(_ builder: SQLPredicateGroupBuilder) -> SQLPredicateGroupBuilder {
        builder.where(
            SQLIdentifier("repo_owner"),
            comparison.binaryOperator(),
            value
        )
    }
    
    func createViewModel() -> SearchFilterViewModel {
        .init(
            key: "author",
            comparison: comparison,
            value: value
        )
    }
}
