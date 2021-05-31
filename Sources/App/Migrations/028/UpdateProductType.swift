import Fluent

struct UpdateProductType: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("products")
            .deleteField("type")
            .field("type", .json)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("products")
            .deleteField("type")
            .field("type", .string, .required)
            .update()
    }
}
