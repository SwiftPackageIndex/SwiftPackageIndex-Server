import Fluent


struct UpdateRepositoryAddLicenseUrl: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("repositories")
            .field("license_url", .string)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("repositories")
            .deleteField("license_url")
            .update()
    }
}
