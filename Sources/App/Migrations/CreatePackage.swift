import Fluent

struct CreatePackage: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Package.schema)
            .id()
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("url", .string, .required)
            .field("last_commit_at", .datetime)
            .create()
            .map { createIndex(database: database, model: Package.schema, field: "url") }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Package.schema).delete()
    }
}
