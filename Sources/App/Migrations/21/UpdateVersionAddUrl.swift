import Fluent


struct UpdateVersionAddUrl: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("versions")
            .field("url", .string)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("versions")
            .deleteField("url")
            .update()
    }
}
