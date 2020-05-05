import Fluent

struct CreateProduct: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("products")
            .id()
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("version_id", .uuid, .references("versions", "id", onDelete: .cascade))
            .field("type", .string, .required)
            .field("name", .string, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("products").delete()
    }
}
