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

struct UpdateRecentReleases7: Migration {
    let dropSQL: SQLQueryString = "DROP MATERIALIZED VIEW recent_releases"

    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        let updatedViewSQL: SQLQueryString =
            """
            -- v7
            CREATE MATERIALIZED VIEW recent_releases AS
            SELECT * FROM (SELECT DISTINCT ON (v.package_id)
                    v.package_id AS package_id,
                    r.owner AS repository_owner,
                    r.name AS repository_name,
                    r.summary AS package_summary,
                    package_name,
                    reference -> 'tag' ->> 'tagName' AS version,
                    commit_date AS released_at,
                    v.url AS release_url,
                    v.release_notes_html AS release_notes_html
                FROM
                    versions v
                    JOIN repositories r ON v.package_id = r.package_id
                WHERE
                    commit_date IS NOT NULL
                    AND package_name IS NOT NULL
                    AND reference ->> 'tag' IS NOT NULL
                ORDER BY
                    v.package_id,
                    v.commit_date DESC) t
            ORDER BY released_at DESC
            LIMIT 100;
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
            -- v6
            CREATE MATERIALIZED VIEW recent_releases AS
            SELECT * from (
              SELECT DISTINCT ON (v.package_id)
                v.package_id AS id,
                r.owner AS repository_owner,
                r.name AS repository_name,
                r.summary AS package_summary,
                package_name,
                reference->'tag'->>'tagName' AS version,
                commit_date AS released_at,
                v.url AS release_url,
                v.release_notes_html as release_notes_html
              FROM versions v
              JOIN repositories r ON v.package_id = r.package_id
              WHERE commit_date IS NOT NULL
                AND package_name IS NOT NULL
                AND reference->>'tag' IS NOT NULL
              ORDER BY v.package_id, v.commit_date desc
            ) t
            order by released_at desc
            limit 100
            """
        return db.raw(dropSQL).run()
            .flatMap { db.raw(oldViewSQL).run() }
    }
}
