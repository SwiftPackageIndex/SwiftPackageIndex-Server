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


struct UpdateRecentPackages4: Migration {
    let dropSQL: SQLQueryString = "DROP MATERIALIZED VIEW recent_packages"

    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        let updatedViewSQL: SQLQueryString =
            """
            -- v4
            CREATE MATERIALIZED VIEW recent_packages AS
            SELECT * FROM ( SELECT DISTINCT ON (p.id)
                    p.id,
                    r.owner AS repository_owner,
                    r.name AS repository_name,
                    r.summary AS package_summary,
                    v.package_name,
                    p.created_at
                FROM
                    packages p
                    JOIN versions v ON v.package_id = p.id
                    JOIN repositories r ON r.package_id = p.id
                WHERE
                    v.package_name IS NOT NULL
                    AND r.owner IS NOT NULL
                    AND r.name IS NOT NULL
                ORDER BY
                    p.id,
                    v.commit_date DESC) t
            ORDER BY
                created_at DESC
            LIMIT 500;
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
            -- v3
            CREATE MATERIALIZED VIEW recent_packages AS
            SELECT * FROM (
              SELECT DISTINCT ON (p.id)
                  p.id,
                  r.owner AS repository_owner,
                  r.name AS repository_name,
                  r.summary AS package_summary,
                  v.package_name,
                  p.created_at
              FROM packages p
              JOIN versions v ON v.package_id = p.id
              JOIN repositories r ON r.package_id = p.id
              WHERE v.package_name IS NOT NULL
                AND r.owner IS NOT NULL
                AND r.name IS NOT NULL
              order by p.id, v.commit_date desc
            ) t
            order by created_at desc
            limit 100
            """
        return db.raw(dropSQL).run()
            .flatMap { db.raw(oldViewSQL).run() }
    }
}
