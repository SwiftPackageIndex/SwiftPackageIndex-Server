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
import SQLKit

struct RemoveVersionCountFromStats: AsyncMigration {
    let dropSQL: SQLQueryString = "DROP MATERIALIZED VIEW stats"

    func prepare(on database: Database) async throws {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }

        try await db.raw(dropSQL).run()
        try await db.raw(
            """
            -- v1
            CREATE MATERIALIZED VIEW stats AS
            SELECT
            NOW() AS date,
            (SELECT COUNT(*) FROM packages) AS package_count
            """).run()
    }

    func revert(on database: Database) async throws {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }

        try await db.raw(dropSQL).run()
        try await db.raw(
            """
            -- v0
            CREATE MATERIALIZED VIEW stats AS
            SELECT
            NOW() AS date,
            (SELECT COUNT(*) FROM packages) AS package_count,
            (SELECT COUNT(*) FROM versions) AS version_count
            """).run()
    }
}
