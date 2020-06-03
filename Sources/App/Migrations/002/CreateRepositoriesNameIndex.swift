import Fluent
import SQLKit


struct CreateRepositoriesNameIndex: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }

        // See https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/176#issuecomment-637710906
        // for details about this index
        return db.raw("CREATE EXTENSION pg_trgm").run()
            .flatMap {
                db.raw("CREATE INDEX idx_repositories_name ON repositories USING gin (name gin_trgm_ops)").run() }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        return
            db.raw("DROP INDEX idx_repositories_name").run()
                .flatMap { db.raw("DROP EXTENSION pg_trgm").run() }
    }
}
