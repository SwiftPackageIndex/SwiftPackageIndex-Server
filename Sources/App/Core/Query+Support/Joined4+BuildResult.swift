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

import Fluent
import Vapor

typealias BuildResult = Joined4<Build, Version, Package, Repository>

extension BuildResult {
    var build: Build { model }
    // It's ok to force unwrap all joined relations, because they
    // are INNER joins, i.e. the relation will exist for every result.
    var version: Version { relation1! }
    var package: Package { relation2! }
    var repository: Repository { relation3! }

    static func query(on database: Database) -> JoinedQueryBuilder<Self> {
        query(
            on: database,
            join: \Version.$id == \Build.$version.$id, method: .inner,
            join: \Package.$id == \Version.$package.$id, method: .inner,
            join: \Repository.$package.$id == \Package.$id, method: .inner
        )
    }

    static func query(on database: Database, buildId: Build.Id) -> EventLoopFuture<Self> {
        query(on: database)
            .filter(\.$id == buildId)
            .first()
            .unwrap(or: Abort(.notFound))
    }
}
