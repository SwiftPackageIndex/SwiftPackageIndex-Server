import Fluent
import Vapor


typealias Platform = String


struct SemVer: Content, Equatable {
    var major: Int
    var minor: Int
    var patch: Int
}

extension SemVer: ExpressibleByStringLiteral {
    // TODO: sas-2020-04-29: This can/should probably be improved...
    // Or should we just save versions as flat strings?
    init(stringLiteral value: StringLiteralType) {
        let parts = value.split(separator: ".").map(String.init).compactMap(Int.init)
        switch parts.count {
            case 1: self = .init(major: parts[0], minor: 0, patch: 0)
            case 2: self = .init(major: parts[0], minor: parts[1], patch: 0)
            case 3: self = .init(major: parts[0], minor: parts[1], patch: parts[2])
            default: self = .init(major: 0, minor: 0, patch: 0)
        }
    }
}

extension SemVer {
    // TODO: having two very similar initialisers is not ideal but we need both at the moment.
    // One to support DB serialization (stringLiteral one) and one to parse incoming data
    // which can fail.
    init?(string: String) {
        let parts = string.split(separator: ".").map(String.init).compactMap(Int.init)
        switch parts.count {
            case 1: self = .init(major: parts[0], minor: 0, patch: 0)
            case 2: self = .init(major: parts[0], minor: parts[1], patch: 0)
            case 3: self = .init(major: parts[0], minor: parts[1], patch: parts[2])
            default: return nil
        }
    }
}


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

    // TODO: sas-2020-04-30: Explore folding branch/rag into an enum with associated value String
    @Field(key: "branch_name")
    var branchName: String?

    @Field(key: "tag_name")
    var tagName: String?

    @Field(key: "package_name")
    var packageName: String?

    @Field(key: "commit")
    var commit: String?

    @Field(key: "supported_platforms")
    var supportedPlatforms: [Platform]

    // TODO: sas-2020-04-29: If we're handling Swift versions specifically here, maybe we should just
    // use an enum? The set of versions should be fairly limited and it might be nicer to query.
    // Although JSON querying with PGSQL is quite good.
    @Field(key: "swift_versions")
    var swiftVersions: [SemVer]

    init() { }

    init(id: UUID? = nil,
         package: Package,
         branchName: String? = nil,
         tagName: String? = nil,
         packageName: String? = nil,
         commit: String? = nil,
         supportedPlatforms: [Platform] = []) throws {
        self.id = id
        self.$package.id = try package.requireID()
        self.branchName = branchName
        self.tagName = tagName
        self.packageName = packageName
        self.commit = commit
        self.supportedPlatforms = supportedPlatforms
    }
}


extension Version: Equatable {
    static func == (lhs: Version, rhs: Version) -> Bool {
        lhs.id == rhs.id
    }
}
