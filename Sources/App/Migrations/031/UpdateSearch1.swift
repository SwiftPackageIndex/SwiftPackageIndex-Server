import Fluent
import SQLKit


struct UpdateSearch1: Migration {
    let dropSQL: SQLQueryString = "DROP MATERIALIZED VIEW search"

    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        let updatedViewSQL: SQLQueryString =
            """
            CREATE MATERIALIZED VIEW search AS
            SELECT
              p.id,
              p.score,
              v.package_name,
              r.name,
              r.owner,
              r.summary,
              r.keywords
            FROM packages p
              JOIN repositories r ON r.package_id = p.id
              JOIN versions v ON v.package_id = p.id
            WHERE v.reference ->> 'branch' = r.default_branch
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
            CREATE MATERIALIZED VIEW search AS
            SELECT
              p.id,
              p.score,
              v.package_name,
              r.name,
              r.owner,
              r.summary
            FROM packages p
              JOIN repositories r ON r.package_id = p.id
              JOIN versions v ON v.package_id = p.id
            WHERE v.reference ->> 'branch' = r.default_branch
            """
        return db.raw(dropSQL).run()
            .flatMap { db.raw(oldViewSQL).run() }
    }
}
