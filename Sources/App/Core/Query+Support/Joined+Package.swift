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
import Vapor


extension Joined where M == Package, R == Repository {
    var package: Package { model }
    var repository: Repository? { relation }

    static func query(on database: Database) -> JoinedQueryBuilder<Joined> {
        query(on: database,
              join: \Repository.$package.$id == \Package.$id,
              method: .left)
    }

    static func query(on database: Database, packageId: Package.Id) async throws -> Self {
        try await query(on: database)
            .filter(Package.self, \.$id, .equal, packageId)
            .first()
            .get()
            .unwrap(or: Abort(.notFound))
    }

    static func query(on database: Database, owner: String, repository: String) -> EventLoopFuture<Self> {
        query(on: database)
            .filter(Repository.self, \.$owner, .custom("ilike"), owner)
            .filter(Repository.self, \.$name, .custom("ilike"), repository)
            .first()
            .unwrap(or: Abort(.notFound))
    }
}
