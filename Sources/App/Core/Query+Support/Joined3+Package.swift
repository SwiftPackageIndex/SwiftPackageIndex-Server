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

import FluentKit


extension Joined3 where M == Package, R1 == Repository, R2 == Version {
    // Force-unwrapping is safe, because the inner joins guarantee the relations
    // to be set, if the query returns any results at all.
    var repository: Repository { relation1! }
    var version: Version { relation2! }

    static func query(on database: Database) -> JoinedQueryBuilder<Joined3> {
        query(on: database,
              join: \Repository.$package.$id == \Package.$id, method: .inner,
              join: \Version.$package.$id == \Package.$id, method: .inner)
    }

    static func query(on database: Database, version latest: Version.Kind) -> JoinedQueryBuilder<Joined3> {
        query(on: database)
            .filter(Version.self, \.$latest == latest)
    }

    static func query(on database: Database,
                      owner: String,
                      repository: String,
                      version latest: Version.Kind) -> JoinedQueryBuilder<Joined3> {
        query(on: database, version: latest)
            .filter(Repository.self, \.$owner, .custom("ilike"), owner)
            .filter(Repository.self, \.$name, .custom("ilike"), repository)
    }
}
