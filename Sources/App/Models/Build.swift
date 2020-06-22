import Fluent
import Vapor


final class Build: Model, Content {
    static let schema = "builds"

    typealias Id = UUID

    // managed fields

    @ID(key: .id)
    var id: Id?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    // reference fields

    @Parent(key: "version_id")
    var version: Version

    // data fields

    @Field(key: "logs")
    var logs: String?

    @Field(key: "platform")
    var platform: Platform?

    @Field(key: "status")
    var status: Build.Status

    @Field(key: "swift_version")
    var swiftVersion: SwiftVersion

    init() { }

    init(id: Id? = nil,
         version: Version,
         logs: String? = nil,
         platform: Platform? = nil,
         status: Status,
         swiftVersion: SwiftVersion) throws {
        self.id = id
        self.$version.id = try version.requireID()
        self.logs = logs
        self.platform = platform
        self.status = status
        self.swiftVersion = swiftVersion
    }

    init(_ dto: PostDTO, _ version: Version) throws {
        self.logs = dto.logs
        self.platform = dto.platform
        self.status = dto.status
        self.swiftVersion = dto.swiftVersion
        self.$version.id = try version.requireID()
    }
    
}


extension Build {
    enum Status: String, Codable {
        case ok
        case failed
    }
}


extension Build {
    struct PostDTO: Decodable {
        var logs: String?
        var platform: Platform?
        var status: Status
        var swiftVersion: SwiftVersion
    }
}
