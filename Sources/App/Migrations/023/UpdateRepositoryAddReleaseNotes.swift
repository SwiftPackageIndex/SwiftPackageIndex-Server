import Fluent


struct UpdateRepositoryAddReleaseNotes: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("repositories")
            .field("releases", .array(of: .json), .sql(.default("{}")))
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("repositories")
            .deleteField("releases")
            .update()
    }
}
