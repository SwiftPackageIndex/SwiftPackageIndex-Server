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

import FluentKit


/// A `JoinedPackage` is a `Package` model joined 1-1 on `Repository` and `Version`,
/// where the joined `Version` is the default branch version. The `Repository` is automatically
/// relationally constrained to a 1:1 relationship via a unique index on its `package_id`.
/// 
/// Both relationships must be present or the `query` method will not select the `Package`.
typealias JoinedPackage = Joined<Package, Repository, Version>

extension Joined where M == Package, R1 == Repository, R2 == Version {
    var repository: Repository? { relation1 }
    var version: Version? { relation2 }

    static func query(on database: Database) -> JoinedQueryBuilder {
        query(on: database,
              join: \Repository.$package.$id == \Package.$id,
              join: \Version.$package.$id == \Package.$id)
            .filter(Version.self, \.$latest == .defaultBranch)
    }
}
