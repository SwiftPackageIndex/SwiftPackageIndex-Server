import Fluent

struct CreateVersion: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("versions")
            .id()
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("package_id", .uuid, .references("packages", "id", onDelete: .cascade))
            .field("branch_name", .string)
            .field("tag_name", .string)
            .field("package_name", .string)
            .field("commit", .string)
            .field("supported_platforms", .array(of: .string))
            .field("swift_versions", .array(of: .json), .sql(.default("{}")))
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("versions").delete()
    }
}
