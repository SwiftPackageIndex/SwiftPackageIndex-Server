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

import Foundation


/// Filters by the date this package was last updated via a commit or an issue/PR being merged/closed.
///
/// Dates must be provided in the `YYYY-MM-DD` format.
///
/// Examples:
/// ```
/// last_activity:2021-10-01  - Last maintenance activity on exactly November 1st 2021
/// last_activity:!2021-10-01 - Last maintenance activity on any day other than November 1st 2021
/// last_activity:>2021-10-01 - Last maintenance activity on any day more recent than November 1st 2021
/// last_activity:<2021-10-01 - Last maintenance activity on any day older than November 1st 2021
/// ```
struct LastActivitySearchFilter: SearchFilterProtocol {
    static var key: SearchFilter.Key = .lastActivity

    var predicate: SearchFilter.Predicate

    init(expression: SearchFilter.Expression) throws {
        guard let date = DateFormatter.filterParseFormatter.date(from: expression.value) else {
            throw SearchFilterError.invalidValueType
        }

        self.predicate = .init(
            operator: expression.operator.defaultPredicateOperator,
            bindableValue: .value(date),
            displayValue: DateFormatter.filterDisplayFormatter.string(from: date)
        )
    }
}
