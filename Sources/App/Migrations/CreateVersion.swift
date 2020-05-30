import Fluent

struct CreateVersion: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("versions")
            // managed fields
            .id()
            .field("created_at", .datetime)
            .field("updated_at", .datetime)

            // reference fields
            .field("package_id", .uuid,
                   .references("packages", "id", onDelete: .cascade))

            // data fields
            .field("commit", .string)
            .field("package_name", .string)
            .field("reference", .json)
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
