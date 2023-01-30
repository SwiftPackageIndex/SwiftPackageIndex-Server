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


struct UpdateRecentReleases2: Migration {
    let dropSQL: SQLQueryString = "DROP MATERIALIZED VIEW recent_releases"

    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        let updatedViewSQL: SQLQueryString =
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
        return db.raw(dropSQL).run()
            .flatMap { db.raw(updatedViewSQL).run() }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        let oldViewSQL: SQLQueryString =
            """
            -- v1
            CREATE MATERIALIZED VIEW recent_releases AS
            SELECT
              v.package_id AS id,
              r.owner AS repository_owner,
              r.name AS repository_name,
              v.package_name,
              MAX(v.commit_date) AS released_at
            FROM versions v
            JOIN repositories r ON v.package_id = r.package_id
            WHERE v.commit_date IS NOT NULL
              AND v.package_name IS NOT NULL
              AND v.reference->>'tag' IS NOT NULL
              AND r.owner IS NOT NULL
              AND r.name IS NOT NULL
            GROUP BY v.package_id, r.owner, r.name, v.package_name
            ORDER BY MAX(v.commit_date) DESC
            LIMIT 100
            """
        return db.raw(dropSQL).run()
            .flatMap { db.raw(oldViewSQL).run() }
    }
}
