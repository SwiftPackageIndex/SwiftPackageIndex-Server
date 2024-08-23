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


struct CreateRecentPackages: AsyncMigration {
    func prepare(on database: Database) async throws {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        try await db.raw(
            """
            -- v0
            CREATE MATERIALIZED VIEW recent_packages AS
            SELECT
              p.id,
              v.package_name,
              MAX(p.created_at) AS created_at
            FROM packages p
            JOIN versions v ON v.package_id = p.id
            WHERE v.package_name IS NOT NULL
            GROUP BY p.id, v.package_name
            ORDER BY MAX(p.created_at) DESC
            LIMIT 100
            """
        ).run()
    }

    func revert(on database: Database) async throws {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        try await db.raw("DROP MATERIALIZED VIEW recent_packages").run()
    }
}
