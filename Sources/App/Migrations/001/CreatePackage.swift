import Fluent

struct CreatePackage: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("packages")
            // managed fields
            .id()
            .field("created_at", .datetime)
            .field("updated_at", .datetime)

            // data fields
            .field("processing_stage", .string)
            .field("score", .int)
            .field("status", .string)
            .field("url", .string, .required).unique(on: "url")

            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("packages").delete()
    }
}
