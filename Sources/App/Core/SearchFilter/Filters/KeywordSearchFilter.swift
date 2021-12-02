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

/// Filters by ensuring the keywords of the package contain the provided keyword.
///
/// Examples:
/// ```
/// keyword:apple  - The package keywords contains the keyword 'apple'
/// keyword:!apple - The package keywords does not contain the keyword 'apple'
/// ```
struct KeywordSearchFilter: SearchFilter {
    static var key: String = "keyword"
    
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
            SQLIdentifier("keyword"),
            comparison == .match ? SQLRaw("ILIKE") : SQLRaw("NOT ILIKE"),
            SQLLiteral.string("%\(value)%")
        )
    }
    
    func createViewModel() -> SearchFilterViewModel {
        .init(
            key: "keywords",
            comparison: comparison,
            value: value
        )
    }
}
