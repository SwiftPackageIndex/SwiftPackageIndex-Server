import Fluent

struct CreatePackage: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("packages")
            // managed fields
            .id()
            .field("created_at", .datetime)
            .field("updated_at", .datetime)

            // data fields
            .field("last_commit_at", .datetime)
            .field("processing_stage", .string)
            .field("status", .string)
            .field("url", .string, .required).unique(on: "url")

            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("packages").delete()
    }
}


// FIXME: squash migrations before launch
struct RemoveLastCommitAt: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("packages")
            .deleteField("last_commit_at")
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("packages")
            .field("last_commit_at", .datetime)
            .update()
    }
}

struct AddScore: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("packages")
            .field("score", .int)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("packages")
            .deleteField("score")
            .update()
    }
}
