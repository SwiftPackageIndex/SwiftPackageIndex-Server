import Fluent
import SQLKit


struct CreateStats: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        return db.raw(
            """
            -- v0
            CREATE MATERIALIZED VIEW stats AS
            SELECT
            NOW() AS date,
            (SELECT COUNT(*) FROM packages) AS package_count,
            (SELECT COUNT(*) FROM versions) AS version_count
            """
        ).run()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        return db.raw("DROP MATERIALIZED VIEW stats").run()
    }
}
