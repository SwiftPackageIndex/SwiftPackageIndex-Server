import Fluent
import Vapor


final class Version: Model, Content {
    static let schema = "versions"

    @ID(key: .id)
    var id: UUID?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Parent(key: "package_id")
    var package: Package

    @Field(key: "branch_name")
    var branchName: String?

    @Field(key: "tag_name")
    var tagName: String?

    @Field(key: "package_name")
    var packageName: String?

    @Field(key: "commit")
    var commit: String?

    // TODO: supportedPlatforms
    // [Platform]

    // TODO: swiftVersions
    // [???]

    init() { }

    init(id: UUID? = nil, package: Package) throws {
        self.id = id
        self.$package.id = try package.requireID()
    }
}
