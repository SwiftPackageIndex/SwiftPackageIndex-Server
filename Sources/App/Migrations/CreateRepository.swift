import Fluent

struct CreateRepository: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("repositories")
            .id()
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("package_id", .uuid, .references("packages", "id", onDelete: .cascade))
            // sas 2020-04-25: Make it a 1-1 relationship
            // TODO: adapt to "official" way, once it's there
            // https://discordapp.com/channels/431917998102675485/684159753189982218/703351108915036171
            .unique(on: "package_id")
            .field("summary", .string)
            .field("default_branch", .string)
            .field("license", .string)
            .field("stars", .int)
            .field("forks", .int)
            .field("forked_from_id", .uuid, .references("repositories", "id"))
            .unique(on: "forked_from_id")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("repositories").delete()
    }
}


// FIXME: squash migrations before launch
struct AddNameOwner: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("repositories")
            .field("name", .string)
            .field("owner", .string)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("repositories")
            .deleteField("name")
            .deleteField("owner")
            .update()
    }
}


struct AddCommitHistoryFields: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("repositories")
            .field("commit_count", .int)
            .field("first_commit_date", .datetime)
            .field("last_commit_date", .datetime)
            .update()
    }


    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("repositories")
            .deleteField("commit_count")
            .deleteField("first_commit_date")
            .deleteField("last_commit_date")
            .update()
    }
}


struct AddActivityFields: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("repositories")
            .field("open_issues", .int)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("repositories")
            .deleteField("open_issues")
            .update()
    }
}
