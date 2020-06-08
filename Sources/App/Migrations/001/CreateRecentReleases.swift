import Fluent
import SQLKit


struct CreateRecentReleases: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        return db.raw(
            """
            -- v0
            CREATE MATERIALIZED VIEW recent_releases AS
            SELECT
              package_id AS id,
              package_name,
              MAX(commit_date) AS released_at
            FROM versions
            WHERE commit_date IS NOT NULL
              AND package_name IS NOT NULL
              AND reference->>'tag' IS NOT NULL
            GROUP BY package_id, package_name
            ORDER BY MAX(commit_date) DESC
            LIMIT 100
            """
        ).run()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        return db.raw("DROP MATERIALIZED VIEW recent_releases").run()
    }
}
