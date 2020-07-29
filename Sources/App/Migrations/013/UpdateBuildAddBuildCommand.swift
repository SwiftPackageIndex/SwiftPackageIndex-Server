import Fluent


struct UpdateBuildAddBuildCommand: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("builds")
            .field("build_command", .string)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("builds")
            .deleteField("build_command")
            .update()
    }
}
