import Fluent


struct UpdateRepositoryAddKeywords: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("repositories")
            .field("keywords", .array(of: .string), .sql(.default("{}")))
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("repositories")
            .deleteField("keywords")
            .update()
    }
}
