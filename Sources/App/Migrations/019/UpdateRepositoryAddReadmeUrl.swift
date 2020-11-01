import Fluent


struct UpdateRepositoryAddReadmeUrl: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("repositories")
            .field("readme_url", .string)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("repositories")
            .deleteField("readme_url")
            .update()
    }
}
