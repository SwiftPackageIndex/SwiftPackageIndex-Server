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


extension SQLSelectBuilder {
    // sas 2020-06-05: workaround `direction: SQLExpression` signature in SQLKit
    // (should be SQLDirection)
    func orderBy(_ expression: SQLExpression, _ direction: SQLDirection = .ascending) -> Self {
        return self.orderBy(SQLOrderBy(expression: expression, direction: direction))
    }

    func column(_ matchType: Search.MatchType) -> Self {
        column(matchType.sqlAlias)
    }

    func column(_ expression: SQLExpression, as alias: SQLExpression) -> Self {
        column(SQLAlias(expression, as: alias))
    }

    func column(_ expression: SQLExpression, as alias: String) -> Self {
        column(SQLAlias(expression, as: SQLIdentifier(alias)))
    }

    func `where`(searchFilters: [SearchFilter]) -> Self {
        self.where(group: { builder in
            searchFilters
                .prefix(20) // just to impose some form of limit
                .reduce(builder) { $1.where($0) }
        })
    }
}
