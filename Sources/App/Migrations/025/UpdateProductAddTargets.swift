import Fluent


struct UpdateProductAddTargets: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("products")
            .field("targets", .array(of: .string), .sql(.default("{}")))
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("products")
            .deleteField("targets")
            .update()
    }
}
