import Fluent


struct UpdateVersionAddPublisedAtReleaseNotes: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("versions")
            .field("published_at", .datetime)
            .field("release_notes", .string)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("versions")
            .deleteField("published_at")
            .deleteField("release_notes")
            .update()
    }
}
