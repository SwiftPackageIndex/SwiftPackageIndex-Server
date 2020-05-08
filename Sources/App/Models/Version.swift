import Fluent
import Vapor


typealias Platform = String


final class Version: Model, Content {
    static let schema = "versions"

    typealias Id = UUID

    @ID(key: .id)
    var id: Id?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Parent(key: "package_id")
    var package: Package

    // TODO: sas-2020-04-30: Explore folding branch/rag into an enum with associated value String
    @Field(key: "branch_name")
    var branchName: String?

    @Field(key: "tag_name")
    var tagName: String?

    @Field(key: "package_name")
    var packageName: String?

    @Field(key: "commit")
    var commit: String?

    // TODO: sas-2020-05-03: currently concatenating os + version - we could save the structure instead
    @Field(key: "supported_platforms")
    var supportedPlatforms: [Platform]

    @Field(key: "swift_versions")
    var swiftVersions: [String]

    init() { }

    init(id: Id? = nil,
         package: Package,
         branchName: String? = nil,
         tagName: String? = nil,
         packageName: String? = nil,
         commit: String? = nil,
         supportedPlatforms: [Platform] = [],
         swiftVersions: [String] = []) throws {
        self.id = id
        self.$package.id = try package.requireID()
        self.branchName = branchName
        self.tagName = tagName
        self.packageName = packageName
        self.commit = commit
        self.supportedPlatforms = supportedPlatforms
        self.swiftVersions = swiftVersions
    }
}


extension Version: Equatable {
    static func == (lhs: Version, rhs: Version) -> Bool {
        lhs.id == rhs.id
    }
}
