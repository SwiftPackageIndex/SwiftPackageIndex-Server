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


extension PackageCollection {
    struct VersionResultGroup {
        var package: App.Package
        var repository: Repository
        var versions: [Version]
    }
}


extension Array where Element == PackageCollection.VersionResult {
    /// Group `VersionResult`s by the package they reference. The grouping key is a
    /// `VersionResult` instead of the grouped by `Package` to allow callers the use
    /// of the `repository` accessor.
    /// - Returns: Array of groups
    func groupedByPackage(sortBy sortKey: SortKey = .url) -> [PackageCollection.VersionResultGroup] {
        // Create a lookup dictionary to be able to refer from the
        // group key `Package` back to its `VersionResult`
        let idLookup = Dictionary(
            map { ($0.package.id, $0) },
            uniquingKeysWith: { _, last in last }
        )
        return Dictionary(grouping: self,
                          by: { $0.package })
            .sorted(by: {
                switch sortKey {
                    case .url:
                        return $0.key.url < $1.key.url
                }
            })
            .map { key, value in
                .init(package: key,
                      repository: idLookup[key.id]!.repository,
                      versions: value.map(\.version))
            }
    }

    enum SortKey {
        case url
    }
}
