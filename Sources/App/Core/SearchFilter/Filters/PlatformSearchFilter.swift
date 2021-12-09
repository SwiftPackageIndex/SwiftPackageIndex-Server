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

/// Filters by the provided platform.
///
/// Examples:
/// ```
/// keyword:ios  - The package supports iOS
/// keyword:macos,linux - The package support macOS and Linux
/// ```
struct PlatformSearchFilter: SearchFilter {
    static var key: String = "platform"

    var comparison: SearchFilterComparison
    var value: Set<Package.PlatformCompatibility>

    init(value: String, comparison: SearchFilterComparison = .match) throws {
        // We don't support `negativeMatch`, because it's unlikely
        // people would want to search for packages that _don't_
        // support a platform.
        guard comparison == .match else {
            throw SearchFilterError.unsupportedComparisonMethod
        }

        self.comparison = comparison
        let values = value.split(separator: ",", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.lowercased() }
            .compactMap(Package.PlatformCompatibility.init(rawValue:))
        let value = Set(values)

        guard !value.isEmpty else { throw SearchFilterError.invalidValueType }

        self.value = value
    }

    func `where`(_ builder: SQLPredicateGroupBuilder) -> SQLPredicateGroupBuilder {
        builder.where(
            SQLIdentifier("platform_compatibility"),
            SQLRaw("@>"),
            SQLBind(value)
        )
    }

    func createViewModel() -> SearchFilterViewModel {
        .init(
            key: "platform compatibility",
            comparison: comparison,
            value: value.map(\.rawValue).joined(separator: ",")
        )
    }
}
