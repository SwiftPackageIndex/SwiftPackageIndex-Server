import Fluent


struct UpdateBuildAddLogURL: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("builds")
            .field("log_url", .string)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("builds")
            .deleteField("log_url")
            .update()
    }
}
