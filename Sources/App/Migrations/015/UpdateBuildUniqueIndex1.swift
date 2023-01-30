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


struct UpdateBuildUniqueIndex1: Migration {
    let newIndexName = "uq:builds.version_id+builds.platform+builds.swift_version+v2"

    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }

        return db.raw("""
            CREATE UNIQUE INDEX "\(raw: newIndexName)"
            ON builds (
                version_id,
                platform,
                (swift_version->'major'),
                (swift_version->'minor')
            )
            """).run()
            .flatMap {
                database.schema("builds")
                    .deleteUnique(on: "version_id", "platform", "swift_version")
                    .update()
            }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }

        return database.schema("builds")
            .unique(on: "version_id", "platform", "swift_version")
            .update()
            .flatMap {
                db.raw(#"DROP INDEX "\#(raw: self.newIndexName)""#).run()
            }
    }
}
