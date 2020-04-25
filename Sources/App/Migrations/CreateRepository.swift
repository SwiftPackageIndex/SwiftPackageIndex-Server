import Fluent

struct CreateRepository: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Repository.schema)
            .id()
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Repository.schema).delete()
    }
}
