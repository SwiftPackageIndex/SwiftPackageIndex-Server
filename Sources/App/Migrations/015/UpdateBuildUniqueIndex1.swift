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
import SQLKit


struct UpdateBuildUniqueIndex1: AsyncMigration {
    let newIndexName = "uq:builds.version_id+builds.platform+builds.swift_version+v2"

    func prepare(on database: Database) async throws {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }

        try await db.raw("""
            CREATE UNIQUE INDEX \(ident: newIndexName)
            ON builds (
                version_id,
                platform,
                (swift_version->'major'),
                (swift_version->'minor')
            )
            """).run()

        try await database.schema("builds")
            .deleteUnique(on: "version_id", "platform", "swift_version")
            .update()
    }

    func revert(on database: Database) async throws {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }

        try await database.schema("builds")
            .unique(on: "version_id", "platform", "swift_version")
            .update()

        try await db.drop(index: newIndexName).run()
    }
}
