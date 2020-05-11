import Fluent
import Vapor


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

    @Field(key: "reference")
    var reference: Reference?

    @Field(key: "package_name")
    var packageName: String?

    @Field(key: "commit")
    var commit: String?

    // TODO: sas-2020-05-03: currently concatenating os + version - we could save the structure instead
    // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/42
    @Field(key: "supported_platforms")
    var supportedPlatforms: [Platform]

    @Field(key: "swift_versions")
    var swiftVersions: [String]

    init() { }

    init(id: Id? = nil,
         package: Package,
         reference: Reference? = nil,
         packageName: String? = nil,
         commit: String? = nil,
         supportedPlatforms: [Platform] = [],
         swiftVersions: [String] = []) throws {
        self.id = id
        self.$package.id = try package.requireID()
        self.reference = reference
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
