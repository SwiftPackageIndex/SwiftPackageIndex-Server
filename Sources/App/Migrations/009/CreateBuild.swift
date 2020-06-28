import Fluent


struct CreateBuild: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("builds")
            // managed fields
            .id()
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            
            // reference fields
            .field("version_id", .uuid,
                   .references("versions", "id", onDelete: .cascade))
            
            // data fields
            .field("logs", .string)
            .field("platform", .json)
            .field("status", .string)
            .field("swift_version", .json)
            
            // constraints
            .unique(on: "version_id", "platform", "swift_version")
            
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("builds").delete()
    }
}
