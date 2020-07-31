import Fluent


struct UpdateVersionAddLatest: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("versions")
            .field("latest", .string)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("versions")
            .deleteField("latest")
            .update()
    }
}
