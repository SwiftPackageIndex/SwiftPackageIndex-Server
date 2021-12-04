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

/// Filters by ensuring the package is compatible with the platform provided.
///
/// Examples:
/// ```
/// platform:ios  - The package is compatible with iOS
/// platform:!ios - The package is not compatible with iOS
/// ```
struct PlatformSearchFilter: SearchFilter {
    static var key: String = "platform"
    
    var comparison: SearchFilterComparison
    var value: Platform.Name
    
    init(value: String, comparison: SearchFilterComparison) throws {
        guard [.match, .negativeMatch].contains(comparison) else {
            throw SearchFilterError.unsupportedComparisonMethod
        }
        
        guard let platform = Platform.Name(rawValue: value.lowercased()) else {
            throw SearchFilterError.invalidValueType
        }
        
        self.comparison = comparison
        self.value = platform
    }
    
    func `where`(_ builder: SQLPredicateGroupBuilder) -> SQLPredicateGroupBuilder {
        let exp = SQLBinaryExpression(
            left: SQLIdentifier("platforms").cast(to: "jsonb"),
            op: SQLRaw("@>"),
            right: SQLBind("[{\"name\":\"\(value.rawValue)\"}]").cast(to: "jsonb")
        )
        
        if comparison == .match {
            // platforms @> []
            return builder.where(exp)
        } else {
            // NOT (platforms @> [])
            return builder.where(SQLInverted(exp: exp))
        }
    }
    
    func createViewModel() -> SearchFilterViewModel {
        .init(
            key: "platform",
            comparison: comparison,
            value: value.description
        )
    }
}

extension SQLExpression {
    func cast(to newType: String) -> SQLExpression {
        SQLCast(exp: self, type: newType)
    }
}

struct SQLCast: SQLExpression {
    let exp: SQLExpression
    let type: String
    
    func serialize(to serializer: inout SQLSerializer) {
        self.exp.serialize(to: &serializer)
        serializer.write("::")
        serializer.write(type)
    }
}

struct SQLInverted: SQLExpression {
    let exp: SQLExpression
    
    func serialize(to serializer: inout SQLSerializer) {
        serializer.write("NOT ")
        SQLGroupExpression(exp).serialize(to: &serializer)
    }
}
