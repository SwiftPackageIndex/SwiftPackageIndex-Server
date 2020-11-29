import Fluent


struct UpdateVersionAddReleaseNotes: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("versions")
            .field("release_notes", .string)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("versions")
            .deleteField("release_notes")
            .update()
    }
}
