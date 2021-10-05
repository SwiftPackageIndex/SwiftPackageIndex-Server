// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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

    @Field(key: "build_command")
    var buildCommand: String?

    @Field(key: "job_url")
    var jobUrl: String?

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
         versionId: Version.Id,
         buildCommand: String? = nil,
         jobUrl: String? = nil,
         logUrl: String? = nil,
         platform: Platform,
         status: Status,
         swiftVersion: SwiftVersion) {
        self.id = id
        self.$version.id = versionId
        self.buildCommand = buildCommand
        self.jobUrl = jobUrl
        self.logUrl = logUrl
        self.platform = platform
        self.status = status
        self.swiftVersion = swiftVersion
    }

    convenience init(id: Id? = nil,
         version: Version,
         buildCommand: String? = nil,
         jobUrl: String? = nil,
         logUrl: String? = nil,
         platform: Platform,
         status: Status,
         swiftVersion: SwiftVersion) throws {
        self.init(id: id,
                  versionId: try version.requireID(),
                  buildCommand: buildCommand,
                  jobUrl: jobUrl,
                  logUrl: logUrl,
                  platform: platform,
                  status: status,
                  swiftVersion: swiftVersion)
    }

    convenience init(_ dto: API.PostCreateBuildDTO, _ version: Version) throws {
        try self.init(version: version,
                      buildCommand: dto.buildCommand,
                      jobUrl: dto.jobUrl,
                      logUrl: dto.logUrl,
                      platform: dto.platform,
                      status: dto.status,
                      swiftVersion: dto.swiftVersion)
    }
    
}


extension Build {
    enum Status: String, Codable {
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
            return Current.triggerBuild(client,
                                        $0.package.url,
                                        platform,
                                        reference,
                                        swiftVersion,
                                        versionId)
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
                // We can't avoid the "duplicate key" error message leaking out to the console
                // so what we do is also log an explainer that it's not a real error.
                // See https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/737
                // Use print so it's not affected by log levels (just like the underlying Postgres
                // error isn't)
                print(#"DISREGARD the above error message about duplicate key violation of constraint "uq:builds.version_id+builds.platform+builds.swift_version+v2" - it is being handled and the error is logged over-eagerly by a subsystem"#)
                // ... find the existing build
                return Build.query(on: database)
                    .filter(\.$platform == self.platform)
                    .filter(.sql(raw: "(swift_version->'major')::int = \(self.swiftVersion.major)"))
                    .filter(.sql(raw: "(swift_version->'minor')::int = \(self.swiftVersion.minor)"))
                    .filter(\.$version.$id == self.$version.id)
                    .all()
                    // ... delete it
                    .flatMap { $0.delete(on: database) }
                    // ... and insert the new build instead
                    .flatMap { self.save(on: database) }
            }
    }
}


// MARK: - Deletion

extension Build {
    static func delete(on database: Database, versionId: Version.Id) -> EventLoopFuture<Int> {
        delete(on: database, deleteSQL: """
            DELETE
            FROM builds b
            USING versions v
            WHERE b.version_id = v.id
              AND v.id = \(bind: versionId)
            RETURNING b.id
            """)
    }

    static func delete(on database: Database,
                       packageId: Package.Id) -> EventLoopFuture<Int> {
        delete(on: database, deleteSQL: """
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
                       versionKind: Version.Kind) -> EventLoopFuture<Int> {
        delete(on: database, deleteSQL: """
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
                       deleteSQL: SQLQueryString) -> EventLoopFuture<Int> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        return db.raw(deleteSQL)
            .all()
            .map { $0.count }
    }

}


// MARK: Fetch build logs

extension Build {

    static func fetchLogs(client: Client, logUrl: String?) -> EventLoopFuture<String?> {
        guard let logUrl = logUrl else {
            return client.eventLoop.future(nil)
        }
        return client.get(URI(string: logUrl))
            .map { $0.body?.asString() }
    }

}


// MARK: - Array extension

extension Array where Element == Build {
    var noneSucceeded: Bool {
        allSatisfy { $0.status != .ok }
    }

    var anySucceeded: Bool {
        !noneSucceeded
    }

    var nonePending: Bool {
        allSatisfy { $0.status.isCompleted }
    }
    
    var anyPending: Bool {
        !nonePending
    }
}
