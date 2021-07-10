import Fluent
import SQLKit


struct UpdateSearch2: Migration {
    let dropSQL: SQLQueryString = "DROP MATERIALIZED VIEW search"

    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        let updatedViewSQL: SQLQueryString =
            """
            CREATE MATERIALIZED VIEW search AS
            SELECT
              p.id AS package_id,
              p.score,
              v.package_name,
              r.name AS repo_name,
              r.owner AS repo_owner,
              r.summary,
              r.keywords,
              r.license,
              r.stars,
              r.last_commit_date,
              v.supported_platforms,
              v.swift_versions
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
              p.id AS package_id,
              p.score,
              v.package_name,
              r.name AS repo_name,
              r.owner AS repo_owner,
              r.summary,
              r.keywords
            FROM packages p
              JOIN repositories r ON r.package_id = p.id
              JOIN versions v ON v.package_id = p.id
            WHERE v.reference ->> 'branch' = r.default_branch
            """
        return db.raw(dropSQL).run()
            .flatMap { db.raw(oldViewSQL).run() }
    }
}
