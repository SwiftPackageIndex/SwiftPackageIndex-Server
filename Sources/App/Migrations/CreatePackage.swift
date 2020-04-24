import Fluent

struct CreatePackage: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("packages")
            .id()
            .field("url", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("last_commit_at", .datetime)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("packages").delete()
    }
}
