import Fluent
import PostgresKit
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

    @Field(key: "log_url")
    var logUrl: String?

    @Field(key: "platform")
    var platform: Platform
    
    @Field(key: "status")
    var status: Build.Status
    
    @Field(key: "swift_version")
    var swiftVersion: SwiftVersion
    
    init() { }
    
    init(id: Id? = nil,
         version: Version,
         logs: String? = nil,
         logUrl: String? = nil,
         platform: Platform,
         status: Status,
         swiftVersion: SwiftVersion) throws {
        self.id = id
        self.$version.id = try version.requireID()
        self.logs = logs
        self.logUrl = logUrl
        self.platform = platform
        self.status = status
        self.swiftVersion = swiftVersion
    }
    
    init(_ dto: PostCreateDTO, _ version: Version) throws {
        self.logs = dto.logs
        self.logUrl = dto.logUrl
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
    
    enum Platform: String, Codable, Equatable {
        case ios
        case macosSpmArm        = "macos-spm-arm"
        case macosXcodebuildArm = "macos-xcodebuild-arm"
        case macosSpm           = "macos-spm"
        case macosXcodebuild    = "macos-xcodebuild"
        case tvos
        case watchos
        case linux

        var name: String {
            switch self {
                case .ios:
                    return "iOS"
                case .macosSpmArm:
                    return "macOS - SPM - ARM"
                case .macosXcodebuildArm:
                    return "macOS - xcodebuild - ARM"
                case .macosSpm:
                    return "macOS - SPM"
                case .macosXcodebuild:
                    return "macOS - xcodebuild"
                case .tvos:
                    return "tvOS"
                case .watchos:
                    return "watchOS"
                case .linux:
                    return "Linux"
            }
        }
    }
}


extension Build {
    struct PostTriggerDTO: Codable {
        var buildTool: BuildTool
        var platform: Platform
        var swiftVersion: SwiftVersion
    }
    
    struct PostCreateDTO: Codable {
        var logs: String?
        var logUrl: String?
        var platform: Platform
        var status: Status
        var swiftVersion: SwiftVersion
    }
}


// MARK: - Triggers


enum BuildTool: String, Codable {
    case spm
    case xcodebuild
}


extension Build {
    
    static func trigger(database: Database,
                        client: Client,
                        buildTool: BuildTool,
                        platform: Build.Platform,
                        swiftVersion: SwiftVersion,
                        versionId: Version.Id) -> EventLoopFuture<HTTPStatus> {
        let version: EventLoopFuture<Version> = Version
            .query(on: database)
            .filter(\.$id == versionId)
            .with(\.$package)
            .first()
            .unwrap(or: Abort(.notFound))
        return version.flatMap {
            guard let reference = $0.reference else {
                return database.eventLoop.future(error: Abort(.internalServerError))
            }
            return Gitlab.Builder.postTrigger(client: client,
                                              cloneURL: $0.package.url,
                                              platform: platform,
                                              reference: reference,
                                              swiftVersion: swiftVersion,
                                              versionID: versionId)
                .map { $0.status }
        }
    }
    
}


extension Build {
    func upsert(on database: Database) -> EventLoopFuture<Void> {
        save(on: database)
            .flatMapError {
                // if we run into a unique key violation ...
                guard let error = $0 as? PostgresError,
                      error.code == .uniqueViolation else {
                    return database.eventLoop.future(error: $0)
                }
                // ... find the existing build
                return Build.query(on: database)
                    .filter(\.$platform == self.platform)
                    .filter(\.$swiftVersion == self.swiftVersion)
                    .filter(\.$version.$id == self.$version.id)
                    .all()
                    // ... delete it
                    .flatMap { $0.delete(on: database) }
                    // ... and insert the new build instead
                    .flatMap { self.save(on: database) }
            }
    }
}



extension Array where Element == Build {
    var noneSucceeded: Bool {
        allSatisfy { $0.status != .ok }
    }

    var anySucceeded: Bool {
        !noneSucceeded
    }
}
