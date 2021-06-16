import Fluent
import SQLKit


struct UpdateRecentReleases6: Migration {
    let dropSQL: SQLQueryString = "DROP MATERIALIZED VIEW recent_releases"

    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        let updatedViewSQL: SQLQueryString =
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
            .flatMap { db.raw(updatedViewSQL).run() }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        let oldViewSQL: SQLQueryString =
            """
            -- v5
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
                v.url AS release_url
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
