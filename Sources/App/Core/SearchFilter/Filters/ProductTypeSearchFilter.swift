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


/// Filters by the provided product type.
///
/// Examples:
/// ```
/// product:executable - The package exports executable product(s).
/// product:library,plugin - The package exports library(ies) and plugin(s).
/// ```

import Foundation

struct ProductTypeFilter: SearchFilterProtocol {
    static var key: SearchFilter.Key = .productType

    var predicate: SearchFilter.Predicate

    init(expression: SearchFilter.Expression) throws {
        // We don't support `isNot`, because it's unlikely
        // people would want to search for packages that _don't_
        // offer a certain product type.
        guard expression.operator == .is else {
            throw SearchFilterError.unsupportedComparisonMethod
        }

        let values = expression.value
            .split(separator: ",", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.lowercased() }
            .compactMap(Package.ProductType.init(rawValue:))
        let value = Set(values)

        guard !value.isEmpty else { throw SearchFilterError.invalidValueType }

        self.predicate = .init(
            operator: .contains,
            bindableValue: .value(value),
            displayValue: value
                .map(\.displayDescription)
                .sorted { $0.lowercased() < $1.lowercased() }
                .pluralized()
        )
    }
}


private extension Package.ProductType {
    var displayDescription: String {
        switch self {
            case .executable:
                return "Executable"
            case .libary:
                return "Library"
            case .plugin:
                return "Plugin"
        }
    }
}
