import Fluent
import SQLKit


struct UpdatePackageStatusNew: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        
        return db.raw("ALTER TABLE packages ALTER COLUMN status SET DEFAULT 'new'").run()
            .flatMap {
                db.raw("ALTER TABLE packages ALTER COLUMN status SET NOT NULL").run()
            }
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        
        return db.raw("ALTER TABLE packages ALTER COLUMN status DROP NOT NULL").run()
            .flatMap {
                db.raw("ALTER TABLE packages ALTER COLUMN status DROP DEFAULT").run()
            }
    }
}
