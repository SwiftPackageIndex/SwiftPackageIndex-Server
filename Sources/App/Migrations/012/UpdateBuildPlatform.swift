import Fluent


struct UpdateBuildPlatform: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("builds")
            .deleteField("platform").field("platform", .string, .required)
            .unique(on: "version_id", "platform", "swift_version")
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("builds")
            .deleteField("platform").field("platform", .json, .required)
            .unique(on: "version_id", "platform", "swift_version")
            .update()
    }
}
