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
}


extension Build {
    enum Status: String, Codable {
        case ok
        case failed
    }

    struct Platform: Codable, Equatable {
        enum Name: String, Codable, Equatable, CaseIterable {
            case ios
            case linux
            case macos
            case tvos
            case watchos

            case unknown
        }
        var name: Name
        var version: String

        static func ios(_ version: String) -> Self { .init(name: .ios, version: version) }
        static func linux(_ version: String) -> Self { .init(name: .linux, version: version) }
        static func macos(_ version: String) -> Self { .init(name: .macos, version: version) }
        static func tvos(_ version: String) -> Self { .init(name: .tvos, version: version) }
        static func watchos(_ version: String) -> Self { .init(name: .watchos, version: version) }
    }
}
