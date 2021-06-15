import Fluent


struct UpdateRepositoryAddTopics: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("repositories")
            .field("topics", .array(of: .string), .sql(.default("{}")))
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("repositories")
            .deleteField("topics")
            .update()
    }
}
