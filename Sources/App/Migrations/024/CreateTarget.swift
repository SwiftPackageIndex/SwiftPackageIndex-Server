import Fluent

struct CreateTarget: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("targets")
            // managed fields
            .id()
            .field("created_at", .datetime)
            .field("updated_at", .datetime)

            // reference fields
            .field("version_id", .uuid,
                   .references("versions", "id", onDelete: .cascade))

            // data fields
            .field("name", .string)

            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("targets").delete()
    }
}
