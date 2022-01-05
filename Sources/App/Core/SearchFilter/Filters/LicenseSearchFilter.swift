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

/// Filters by the license of the package.
///
/// Examples:
/// ```
/// license:compatible   - The license is compatible with the app store
/// license:!compatible - The license is unknown, none is provided, or the one provided is not compatible with the app store
/// license:mit - The package specifically uses the MIT license (any can be used)
/// ```
struct LicenseSearchFilter: SearchFilter {
    enum FilterType: Equatable {
        case kind(License.Kind)
        case license(License)
        
        init?(rawValue: String) {
            if let kind = License.Kind(rawValue: rawValue) {
                self = .kind(kind)
            } else if let license = License(rawValue: rawValue) {
                self = .license(license)
            } else {
                return nil
            }
        }
    }
    
    static var key: SearchFilterKey = .license

    var bindableValue: Encodable
    var displayValue: String
    var `operator`: SearchFilterComparison

    init(value: String, comparison: SearchFilterComparison) throws {
        guard let filterType = FilterType(rawValue: value) else {
            throw SearchFilterError.invalidValueType
        }
        
        guard [.match, .negativeMatch].contains(comparison) else {
            throw SearchFilterError.unsupportedComparisonMethod
        }

        switch filterType {
            case .kind(let kind):
                self.bindableValue = License.allCases
                    .filter { $0.licenseKind == kind }
                    .map(\.rawValue)
                self.displayValue = kind.userFacingString
            case .license(let license):
                self.bindableValue = [license.rawValue]
                self.displayValue = license.shortName
        }
        self.operator = comparison
    }

    func `where`(_ builder: SQLPredicateGroupBuilder) -> SQLPredicateGroupBuilder {
        builder.where(
            Self.key.sqlIdentifier,
            // override default operators .equal/.notEqual
            `operator` == .match ? .in : .notIn,
            SQLBind(bindableValue)
        )
    }
}
