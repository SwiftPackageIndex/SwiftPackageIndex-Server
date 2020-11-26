import Fluent


struct UpdateRepositoryAddIsArchived: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("repositories")
            .field("is_archived", .string)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("repositories")
            .deleteField("is_archived")
            .update()
    }
}
