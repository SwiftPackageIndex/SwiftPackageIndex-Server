// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Dependencies
import Fluent
import PostgresKit
import Vapor


final class Build: @unchecked Sendable, Model, Content {
    static let schema = "builds"

    typealias Id = UUID

    // managed fields

    @ID(key: .id)
    var id: Id?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    // periphery:ignore
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    // reference fields

    @OptionalParent(key: "doc_upload_id")
    var docUpload: DocUpload?

    @Parent(key: "version_id")
    var version: Version

    // data fields

    @Field(key: "build_command")
    var buildCommand: String?

    @Field(key: "build_date")
    var buildDate: Date?

    @Field(key: "build_duration")
    var buildDuration: Double?

    @Field(key: "build_errors")
    var buildErrors: BuildErrors?

    @Field(key: "builder_version")
    var builderVersion: String?

    @Field(key: "commit_hash")
    var commitHash: String?

    @Field(key: "job_url")
    var jobUrl: String?

    @Field(key: "log_url")
    var logUrl: String?

    @Field(key: "platform")
    var platform: Platform

    @Field(key: "runner_id")
    var runnerId: String?

    @Field(key: "status")
    var status: Status

    @Field(key: "swift_version")
    var swiftVersion: SwiftVersion

    init() { }

    init(id: Id? = nil,
         versionId: Version.Id,
         buildCommand: String? = nil,
         buildDuration: Double? = nil,
         buildErrors: BuildErrors? = nil,
         jobUrl: String? = nil,
         logUrl: String? = nil,
         platform: Platform,
         runnerId: String? = nil,
         status: Status,
         swiftVersion: SwiftVersion) {
        self.id = id
        self.$version.id = versionId
        self.buildCommand = buildCommand
        self.buildDuration = buildDuration
        self.buildErrors = buildErrors
        self.jobUrl = jobUrl
        self.logUrl = logUrl
        self.platform = platform
        self.runnerId = runnerId
        self.status = status
        self.swiftVersion = swiftVersion
    }

    convenience init(id: Id? = nil,
                     version: Version,
                     buildCommand: String? = nil,
                     buildDuration: Double? = nil,
                     buildErrors: BuildErrors? = nil,
                     jobUrl: String? = nil,
                     logUrl: String? = nil,
                     platform: Platform,
                     runnerId: String? = nil,
                     status: Status,
                     swiftVersion: SwiftVersion) throws {
        self.init(id: id,
                  versionId: try version.requireID(),
                  buildCommand: buildCommand,
                  buildDuration: buildDuration,
                  buildErrors: buildErrors,
                  jobUrl: jobUrl,
                  logUrl: logUrl,
                  platform: platform,
                  runnerId: runnerId,
                  status: status,
                  swiftVersion: swiftVersion)
    }

}


extension Build {
    enum Status: String, Codable, CustomStringConvertible {
        case ok
        case failed
        case infrastructureError
        case triggered
        case timeout

        var isCompleted: Bool {
            switch self {
                case .ok, .failed, .timeout:
                    return true
                case .infrastructureError, .triggered:
                    return false
            }
        }

        var description: String {
            switch self {
                case .ok: return "Successful"
                case .failed: return "Failed"
                case .infrastructureError: return "Infrastructure Error"
                case .triggered: return "Triggered"
                case .timeout: return "Timed Out"
            }
        }
    }
}


// MARK: - Triggers


extension Build {

    struct TriggerResponse: Content {
        var status: HTTPStatus
        var webUrl: String?
    }

    static func trigger(database: Database,
                        buildId: Build.Id,
                        isDocBuild: Bool,
                        platform: Build.Platform,
                        swiftVersion: SwiftVersion,
                        versionId: Version.Id) async throws -> TriggerResponse {
        let version = try await Version
            .query(on: database)
            .filter(\.$id == versionId)
            .with(\.$package)
            .first()
            .unwrap(or: Abort(.notFound))

        @Dependency(\.buildSystem) var buildSystem
        return try await buildSystem.triggerBuild(buildId,
                                                  version.package.url,
                                                  isDocBuild,
                                                  platform,
                                                  version.reference,
                                                  swiftVersion,
                                                  versionId)
    }

}


extension Build {
    static func query(on database: Database,
                      platform: Platform,
                      swiftVersion: SwiftVersion,
                      versionId: Version.Id) async throws -> Build? {
        let builds = try await Build.query(on: database)
            .filter(\.$platform == platform)
            .filter(.sql(unsafeRaw: "(swift_version->'major')::int = \(swiftVersion.major)"))
            .filter(.sql(unsafeRaw: "(swift_version->'minor')::int = \(swiftVersion.minor)"))
            .filter(\.$version.$id == versionId)
            .all()
        guard builds.count <= 1 else {
            throw AppError.genericError(nil, "More than one build record per (platform/swiftVersion/versionId) found")
        }
        return builds.first
    }
}


// MARK: - Deletion

extension Build {
    static func delete(on database: Database, versionId: Version.Id) async throws -> Int {
        try await delete(on: database, deleteSQL: """
            DELETE
            FROM builds b
            USING versions v
            WHERE b.version_id = v.id
              AND v.id = \(bind: versionId)
            RETURNING b.id
            """)
    }

    static func delete(on database: Database,
                       packageId: Package.Id) async throws -> Int {
        try await delete(on: database, deleteSQL: """
            DELETE
            FROM builds b
            USING versions v, packages p
            WHERE b.version_id = v.id
              AND v.package_id = p.id
              AND p.id = \(bind: packageId)
            RETURNING b.id
            """)
    }

    static func delete(on database: Database,
                       packageId: Package.Id,
                       versionKind: Version.Kind) async throws -> Int {
        try await delete(on: database, deleteSQL: """
            DELETE
            FROM builds b
            USING versions v, packages p
            WHERE b.version_id = v.id
              AND v.package_id = p.id
              AND p.id = \(bind: packageId)
              AND v.latest = \(bind: versionKind.rawValue)
            RETURNING b.id
            """)
    }

    static func delete(on database: Database,
                       deleteSQL: SQLQueryString) async throws -> Int {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        return try await db.raw(deleteSQL)
            .all()
            .count
    }

}


// MARK: Fetch build logs

extension Build {

    static func fetchLogs(client: Client, logUrl: String?) async throws -> String? {
        guard let logUrl = logUrl else { return nil }
        return try await client.get(URI(string: logUrl)).body?.asString()
    }

}
