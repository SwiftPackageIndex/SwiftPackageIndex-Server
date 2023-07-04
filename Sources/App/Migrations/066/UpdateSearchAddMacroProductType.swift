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


struct UpdateSearchAddMacroProductType: AsyncMigration {
    let dropSQL: SQLQueryString = "DROP MATERIALIZED VIEW search"

    func prepare(on database: Database) async throws {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }

        // Create an index on targets.version_id - this speeds up search view creation
        // dramatically.
        try await db.raw("CREATE INDEX idx_targets_version_id ON targets (version_id)")
            .run()

        // ** IMPORTANT **
        // When updating the query underlying the materialized view, make sure to also
        // update the matching performance test in QueryPerformanceTests.test_Search_refresh!
        try await db.raw(dropSQL).run()
        try await db.raw("""
            -- v11
            CREATE MATERIALIZED VIEW search AS
            SELECT
              p.id AS package_id,
              p.platform_compatibility,
              p.score,
              r.keywords,
              r.last_commit_date,
              r.license,
              r.name AS repo_name,
              r.owner AS repo_owner,
              r.stars,
              r.last_activity_at,
              r.summary,
              v.package_name,
              ARRAY_LENGTH(doc_archives, 1) >= 1 AS has_docs,
              ARRAY(
                SELECT DISTINCT JSONB_OBJECT_KEYS(type) FROM products WHERE products.version_id = v.id
                UNION
                SELECT * FROM (
                  SELECT DISTINCT JSONB_OBJECT_KEYS(type) AS "type" FROM targets
                  WHERE targets.version_id = v.id) AS macro_targets
                WHERE type = 'macro'
              ) AS product_types,
              ARRAY(SELECT DISTINCT name FROM products WHERE products.version_id = v.id) AS product_names,
              TO_TSVECTOR(CONCAT_WS(' ', COALESCE(v.package_name, ''), r.name, COALESCE(r.summary, ''), ARRAY_TO_STRING(r.keywords, ' '))) AS tsvector
            FROM packages p
              JOIN repositories r ON r.package_id = p.id
              JOIN versions v ON v.package_id = p.id
            WHERE v.reference ->> 'branch' = r.default_branch
            """).run()
    }

    func revert(on database: Database) async throws {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }

        try await db.raw(dropSQL).run()
        try await db.raw("""
            -- v10
            CREATE MATERIALIZED VIEW search AS
            SELECT
              p.id AS package_id,
              p.platform_compatibility,
              p.score,
              r.keywords,
              r.last_commit_date,
              r.license,
              r.name AS repo_name,
              r.owner AS repo_owner,
              r.stars,
              r.last_activity_at,
              r.summary,
              v.package_name,
              ARRAY_LENGTH(doc_archives, 1) >= 1 AS has_docs,
              ARRAY(SELECT DISTINCT JSONB_OBJECT_KEYS(type) FROM products WHERE products.version_id = v.id) AS product_types,
              ARRAY(SELECT DISTINCT name FROM products WHERE products.version_id = v.id) AS product_names,
              TO_TSVECTOR(CONCAT_WS(' ', COALESCE(v.package_name, ''), r.name, COALESCE(r.summary, ''), ARRAY_TO_STRING(r.keywords, ' '))) AS tsvector
            FROM packages p
              JOIN repositories r ON r.package_id = p.id
              JOIN versions v ON v.package_id = p.id
            WHERE v.reference ->> 'branch' = r.default_branch
            """).run()

        try await db.raw("DROP INDEX idx_targets_version_id").run()
    }
}
