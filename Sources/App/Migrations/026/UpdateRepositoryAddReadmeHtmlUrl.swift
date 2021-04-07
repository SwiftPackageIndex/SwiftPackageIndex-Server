import Fluent


struct UpdateRepositoryAddReadmeHtmlUrl: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("repositories")
            .field("readme_html_url", .string)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("repositories")
            .deleteField("readme_html_url")
            .update()
    }
}
