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


struct Joined5<M: Model, R1: Joinable, R2: Joinable, R3: Joinable, R4: Joinable>: ModelInitializable {
    private(set) var model: M
}


extension Joined5 {
    /// Query method that joins R1, R2, R3, and R4 on M via the given join filters.
    /// - Returns: a `JoinedQueryBuilder<Self>`
    static func query(
        on database: Database,
        join joinFilter1: ComplexJoinFilter,
        method method1: DatabaseQuery.Join.Method = .inner,
        join joinFilter2: ComplexJoinFilter,
        method method2: DatabaseQuery.Join.Method = .inner,
        join joinFilter3: ComplexJoinFilter,
        method method3: DatabaseQuery.Join.Method = .inner,
        join joinFilter4: ComplexJoinFilter,
        method method4: DatabaseQuery.Join.Method = .inner) -> JoinedQueryBuilder<Self> {
            .init(
                queryBuilder: M.query(on: database)
                    .join(R1.self, on: joinFilter1, method: method1)
                    .join(R2.self, on: joinFilter2, method: method2)
                    .join(R3.self, on: joinFilter3, method: method3)
                    .join(R4.self, on: joinFilter4, method: method4)
            )
    }

    var relation1: R1? { try? model.joined(R1.self) }
    var relation2: R2? { try? model.joined(R2.self) }
    var relation3: R3? { try? model.joined(R3.self) }
    var relation4: R4? { try? model.joined(R4.self) }
}


extension Joined5 where M == Build, R1 == Version, R2 == Package, R3 == Repository, R4 == DocUpload {
    static func query(on database: Database, owner: String, repository: String) -> JoinedQueryBuilder<Self> {
        query(on: database,
              join: \Version.$id == \Build.$version.$id, method: .inner,
              join: \Package.$id == \Version.$package.$id, method: .inner,
              join: \Repository.$package.$id == \Package.$id, method: .inner,
              join: \Build.$id == \DocUpload.$build.$id, method: .left)
        .filter(Version.self, \Version.$latest != nil)
        .filter(Repository.self, \.$owner, .custom("ilike"), owner)
        .filter(Repository.self, \.$name, .custom("ilike"), repository)
    }

    // periphery:ignore
    var build: Build { model }
    // periphery:ignore
    var version: Version { relation1! }  // ! safe due to inner join
    // periphery:ignore
    var package: Package { relation2! }  // ! safe due to inner join
    // periphery:ignore
    var repository: Repository { relation3! }  // ! safe due to inner join
    // periphery:ignore
    var docUpload: DocUpload? { relation4 }  // optional due to left join
}
