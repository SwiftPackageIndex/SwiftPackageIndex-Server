import Fluent


struct UpdateRepositoryAddOwnerNameAndOwnerAvatarUrlAndIsInOrganizationFlag: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("repositories")
            .field("owner_name", .string)
            .field("owner_avatar_url", .string)
            .field("is_in_organization", .bool)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("repositories")
            .deleteField("owner_name")
            .deleteField("owner_avatar_url")
            .deleteField("is_in_organization")
            .update()
    }
}
