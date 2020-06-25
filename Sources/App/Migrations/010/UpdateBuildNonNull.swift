import Fluent


struct UpdateBuildNonNull: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("builds")
            .deleteField("platform").field("platform", .json, .required)
            .deleteField("status").field("status", .string, .required)
            .deleteField("swift_version").field("swift_version", .json, .required)
            .unique(on: "version_id", "platform", "swift_version")
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("builds")
            .deleteField("platform").field("platform", .json)
            .deleteField("status").field("status", .string)
            .deleteField("swift_version").field("swift_version", .json)
            .unique(on: "version_id", "platform", "swift_version")
            .update()
    }
}
