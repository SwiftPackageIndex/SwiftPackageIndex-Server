import Fluent


struct UpdateBuildRemoveLogs: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("builds")
            .deleteField("logs")
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("builds")
            .field("logs", .string)
            .update()
    }
}
