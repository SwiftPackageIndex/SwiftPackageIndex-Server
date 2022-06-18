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
/// type:executable - The package exports executable product(s).
/// type:plugin - The package exports plugin product(s).
/// ```

import Foundation
import SQLKit

struct ProductTypeSearchFilter: SearchFilterProtocol {
    static var key: SearchFilter.Key = .productType

    var predicate: SearchFilter.Predicate
    let productType: ProductType

    init(expression: SearchFilter.Expression) throws {
        // We don't support `isNot`, because it's unlikely
        // people would want to search for packages that _don't_
        // offer a certain product type.
        guard expression.operator == .is else {
            throw SearchFilterError.unsupportedComparisonMethod
        }

        // We support searching for a single type to lighten the load
        // on the search and because it's somewhat niche use case to
        // search for multiple product types
        guard let value = ProductType(rawValue: expression.value) else {
            throw SearchFilterError.invalidValueType
        }

        productType = value

        self.predicate = .init(
            operator: .jsonKeyExists,
            bindableValue: .value(value.rawValue),
            displayValue: value.displayDescription
        )
    }
}


extension ProductTypeSearchFilter {
    enum ProductType: String, Codable, CaseIterable {
        case executable
        case library
        case plugin

        var displayDescription: String {
            switch self {
                case .executable:
                    return "Executable"
                case .library:
                    return "Library"
                case .plugin:
                    return "Plugin"
            }
        }
    }
}


extension ProductTypeSearchFilter {
    var viewModel: SearchFilter.ViewModel {
        let article: String
        switch productType {
        case .executable: article = "an"
        default: article = "a"
        }
        return .init(key: "Package products",
              operator: "contain",
              value: "\(article) \(predicate.displayValue)")
    }
}
