import Fluent


struct UpdateBuildAddJobUrl: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("builds")
            .field("job_url", .string)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("builds")
            .deleteField("job_url")
            .update()
    }
}
