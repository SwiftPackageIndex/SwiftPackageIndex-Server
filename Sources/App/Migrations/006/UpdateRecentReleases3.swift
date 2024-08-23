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


struct UpdateRecentReleases3: AsyncMigration {
    let dropSQL: SQLQueryString = "DROP MATERIALIZED VIEW recent_releases"

    func prepare(on database: Database) async throws {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        let updatedViewSQL: SQLQueryString =
            """
            -- v3
            CREATE MATERIALIZED VIEW recent_releases AS
            SELECT
              v.package_id AS id,
              t.repository_owner,
              t.repository_name,
              t.package_summary,
              v.package_name,
              reference->'tag'->>'tagName' AS version,
              released_at
            FROM (
              SELECT
                v.package_id,
                r.owner AS repository_owner,
                r.name AS repository_name,
                r.summary AS package_summary,
                package_name,
                MAX(commit_date) AS released_at
              FROM versions v
              JOIN repositories r ON v.package_id = r.package_id
              WHERE commit_date IS NOT NULL
                AND package_name IS NOT NULL
                AND reference->>'tag' IS NOT NULL
              GROUP BY v.package_id, r.owner, r.name, r.summary, v.package_name
            ) AS t
            JOIN versions v ON t.package_id = v.package_id AND t.released_at = v.commit_date
            WHERE reference->'tag'->>'tagName' IS NOT NULL
            ORDER BY released_at DESC
            LIMIT 100
            """
        try await db.raw(dropSQL).run()
        try await db.raw(updatedViewSQL).run()
    }

    func revert(on database: Database) async throws {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        let oldViewSQL: SQLQueryString =
            """
            -- v2
            CREATE MATERIALIZED VIEW recent_releases AS
            SELECT
              v.package_id AS id,
              t.repository_owner,
              t.repository_name,
              v.package_name,
              reference->'tag'->>'tagName' AS version,
              released_at
            FROM (
              SELECT
                v.package_id,
                r.owner AS repository_owner,
                r.name AS repository_name,
                package_name,
                MAX(commit_date) AS released_at
              FROM versions v
              JOIN repositories r ON v.package_id = r.package_id
              WHERE commit_date IS NOT NULL
                AND package_name IS NOT NULL
                AND reference->>'tag' IS NOT NULL
              GROUP BY v.package_id, r.owner, r.name, v.package_name
            ) AS t
            JOIN versions v ON t.package_id = v.package_id AND t.released_at = v.commit_date
            WHERE reference->'tag'->>'tagName' IS NOT NULL
            ORDER BY released_at DESC
            LIMIT 100
            """
        try await db.raw(dropSQL).run()
        try await db.raw(oldViewSQL).run()
    }
}
