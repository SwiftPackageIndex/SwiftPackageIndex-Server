import Fluent

struct CreateRepository: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Repository.schema)
            .id()
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("package_id", .uuid, .references(Package.schema, "id"))
            // sas 2020-04-25: Make it a 1-1 relationship
            // TODO: adapt to "official" way, once it's there
            // https://discordapp.com/channels/431917998102675485/684159753189982218/703351108915036171
            .unique(on: "package_id")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Repository.schema).delete()
    }
}
