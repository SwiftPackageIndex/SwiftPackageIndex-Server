import Fluent
import SQLKit


struct UpdateBuildUniqueIndex1: Migration {
    let newIndexName = "uq:builds.version_id+builds.platform+builds.swift_version+v2"

    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }

        return db.raw("""
            CREATE UNIQUE INDEX "\(newIndexName)"
            ON builds (
                version_id,
                platform,
                (swift_version->'major'),
                (swift_version->'minor')
            )
            """).run()
            .flatMap {
                database.schema("builds")
                    .deleteUnique(on: "version_id", "platform", "swift_version")
                    .update()
            }
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }

        return database.schema("builds")
            .unique(on: "version_id", "platform", "swift_version")
            .update()
            .flatMap {
                db.raw(#"DROP INDEX "\#(self.newIndexName)""#).run()
            }
    }
}
