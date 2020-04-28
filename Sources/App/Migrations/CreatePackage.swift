import Fluent

struct CreatePackage: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("packages")
            .id()
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("url", .string, .required)
            .field("status", .string)
            .field("last_commit_at", .datetime)
            .unique(on: "url")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("packages").delete()
    }
}
