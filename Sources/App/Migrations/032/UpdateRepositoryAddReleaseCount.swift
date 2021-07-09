import Fluent


struct UpdateRepositoryAddReleaseCount: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("repositories")
            .field("release_count", .int)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("repositories")
            .deleteField("release_count")
            .update()
    }
}
