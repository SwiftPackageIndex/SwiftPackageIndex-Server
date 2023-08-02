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

extension Joined4 where M == Package, R1 == Repository, R2 == Version, R3 == Product {
    // periphery:ignore
    var package: Package { model }
    // Safe to force unwrap all relationshipts due to inner joins
    // periphery:ignore
    var repository: Repository { relation1! }
    // periphery:ignore
    var version: Version { relation2! }
    // periphery:ignore
    var product: Product { relation3! }

    static func query(on database: Database, owner: String, repository: String) -> JoinedQueryBuilder<Self> {
        query(on: database,
              join: \Repository.$package.$id == \Package.$id, method: .inner,
              join: \Version.$package.$id == \Package.$id, method: .inner,
              join: \Product.$version.$id == \Version.$id, method: .inner)
            .filter(Version.self, \Version.$latest == .defaultBranch)
            .filter(Repository.self, \.$owner, .custom("ilike"), owner)
            .filter(Repository.self, \.$name, .custom("ilike"), repository)
    }
}

extension Joined4 where M == Package, R1 == Repository, R2 == Version, R3 == Target {
    // periphery:ignore
    var package: Package { model }
    // Safe to force unwrap all relationshipts due to inner joins
    // periphery:ignore
    var repository: Repository { relation1! }
    // periphery:ignore
    var version: Version { relation2! }
    // periphery:ignore
    var target: Target { relation3! }

    static func query(on database: Database, owner: String, repository: String) -> JoinedQueryBuilder<Self> {
        query(on: database,
              join: \Repository.$package.$id == \Package.$id, method: .inner,
              join: \Version.$package.$id == \Package.$id, method: .inner,
              join: \Target.$version.$id == \Version.$id, method: .inner)
        .filter(Version.self, \Version.$latest == .defaultBranch)
        .filter(Repository.self, \.$owner, .custom("ilike"), owner)
        .filter(Repository.self, \.$name, .custom("ilike"), repository)
    }
}
