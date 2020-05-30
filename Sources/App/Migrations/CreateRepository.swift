import Fluent

struct CreateRepository: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("repositories")
            // managed fields
            .id()
            .field("created_at", .datetime)
            .field("updated_at", .datetime)

            // reference fields
            .field("forked_from_id", .uuid,
                   .references("repositories", "id")).unique(on: "forked_from_id")
            .field("package_id", .uuid,
                   .references("packages", "id", onDelete: .cascade)).unique(on: "package_id")

            // data fields
            .field("default_branch", .string)
            .field("forks", .int)
            .field("license", .string)
            .field("stars", .int)
            .field("summary", .string)
            
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
            .field("last_issue_closed_at", .datetime)
            .field("last_pull_request_closed_at", .datetime)
            .field("open_issues", .int)
            .field("open_pull_requests", .int)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("repositories")
            .deleteField("last_issue_closed_at")
            .deleteField("last_pull_request_closed_at")
            .deleteField("open_issues")
            .deleteField("open_pull_requests")
            .update()
    }
}


struct AddAuthors: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("repositories")
            .field("authors", .array(of: .json), .sql(.default("{}")))
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("repositories")
            .deleteField("authors")
            .update()
    }
}
