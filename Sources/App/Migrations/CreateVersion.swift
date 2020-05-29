import Fluent

struct CreateVersion: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("versions")
            .id()
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("package_id", .uuid, .references("packages", "id", onDelete: .cascade))
            .field("reference", .json)
            .field("package_name", .string)
            .field("commit", .string)
            .field("supported_platforms", .array(of: .json), .sql(.default("{}")))
            .field("swift_versions", .array(of: .string), .sql(.default("{}")))
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("versions").delete()
    }
}


// FIXME: squash migrations before launch
struct AddCommitDate: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("versions")
            .field("commit_date", .datetime)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("versions")
            .deleteField("commit_date")
            .update()
    }
}


struct ChangeSwiftVersions: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("versions")
            .deleteField("swift_versions")
            .field("swift_versions", .array(of: .json), .sql(.default("{}")))
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("versions")
            .deleteField("swift_versions")
            .field("swift_versions", .array(of: .string), .sql(.default("{}")))
            .update()
    }
}
