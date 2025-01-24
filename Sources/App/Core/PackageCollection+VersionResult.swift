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

import Fluent
import Vapor


extension PackageCollection {
    typealias VersionResult = Ref3<Joined3<App.Version,
                                           App.Package,
                                           Repository>,
                                   App.Build,
                                   App.Product,
                                   App.Target>
}


extension PackageCollection.VersionResult {
    var builds: [App.Build] { version.builds }
    var package: Package {
        // safe to force unwrap due to "inner" join
        model.package!
    }
    var products: [App.Product] { version.products }
    var repository: Repository {
        // safe to force unwrap due to "inner" join
        model.repository!
    }
    var targets: [App.Target] { version.targets }
    var version: App.Version { model.version }

    static func query(on database: Database, filterBy filter: PackageCollection.Filter, limit maxResults: Int? = nil) async throws -> [Self] {
        let query = M
            .query(
                on: database,
                join: \App.Package.$id == \App.Version.$package.$id,
                join: \Repository.$package.$id == \App.Package.$id
            )
            .with(\.$builds)
            .with(\.$products)
            .with(\.$targets)
            .filter(App.Version.self, \App.Version.$latest ~~ [.release, .preRelease])

        switch filter {
            case let .author(owner):
                query.filter(Repository.self, \Repository.$owner, .custom("ilike"), owner)
            case let .keyword(keyword):
                query.filter(Repository.self, \Repository.$keywords, .custom("@>"), [keyword])
            case let .customCollection(key):
                query
                    .join(CustomCollectionPackage.self, on: \Package.$id == \CustomCollectionPackage.$package.$id)
                    .join(CustomCollection.self, on: \CustomCollection.$id == \CustomCollectionPackage.$customCollection.$id)
                    .filter(CustomCollection.self, \.$key == key)
            case let .urls(packageURLs):
                query.filter(App.Package.self, \.$url ~~ packageURLs)
        }

        if let maxResults = maxResults {
            query.limit(maxResults)
        }

        return try await query.all()
            .map(Self.init(model:))
    }
}


private extension Joined3 where M == Version, R1 == Package, R2 == Repository {
    var version: Version { model }
    var package: Package? { try? model.joined(R1.self) }
    var repository: Repository? { try? model.joined(R2.self) }
}
