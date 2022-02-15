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
import SQLKit
import Vapor


struct TriggerBuildsCommand: Command {
    let defaultLimit = 1

    struct Signature: CommandSignature {
        @Option(name: "limit", short: "l")
        var limit: Int?
        @Flag(name: "force", short: "f", help: "override pipeline capacity check and downscaling (--id only)")
        var force: Bool
        @Option(name: "package-id", short: "p")
        var packageId: Package.Id?
    }

    var help: String { "Trigger package builds" }

    enum Mode {
        case limit(Int)
        case packageId(Package.Id, force: Bool)
    }

    func run(using context: CommandContext, signature: Signature) throws {
        let limit = signature.limit ?? defaultLimit
        let force = signature.force
        let logger = Logger(component: "trigger-builds")

        Self.resetMetrics()

        let mode = signature.packageId
            .map { Mode.packageId($0, force: force) } ?? .limit(limit)
        if force, case .limit = mode {
            logger.warning("--force has no effect when used with --limit")
        }

        try triggerBuilds(on: context.application.db,
                          client: context.application.client,
                          logger: logger,
                          mode: mode).wait()
        do {
            try AppMetrics.push(client: context.application.client,
                                logger: context.application.logger,
                                jobName: "trigger-builds").wait()
        } catch {
            logger.warning("\(error.localizedDescription)")
        }
    }
}


extension TriggerBuildsCommand {
    static func resetMetrics() {
        AppMetrics.buildTriggerCount?.set(0)
        AppMetrics.buildTrimCount?.set(0)
    }
}


/// High level build trigger function that either triggers builds for a given set of package ids
/// or fetches a number of package ids via `fetchBuildCandidates` and triggers those.
/// - Parameters:
///   - database: `Database` handle used for database access
///   - client: `Client` used for http request
///   - logger: `Logger` used for logging
///   - parameter: `BuildTriggerCommand.Parameter` holding either a list of package ids
///   or a fetch limit for candidate selection.
/// - Returns: `EventLoopFuture<Void>` future
func triggerBuilds(on database: Database,
                   client: Client,
                   logger: Logger,
                   mode: TriggerBuildsCommand.Mode) -> EventLoopFuture<Void> {
    let start = DispatchTime.now().uptimeNanoseconds
    switch mode {
        case .limit(let limit):
            logger.info("Triggering builds (limit: \(limit)) ...")
            return fetchBuildCandidates(database)
                .map { candidates in
                    AppMetrics.buildCandidatesCount?.set(candidates.count)
                    return Array(candidates.prefix(limit))
                }
                .flatMap { triggerBuilds(on: database,
                                         client: client,
                                         logger: logger,
                                         packages: $0)
                }
                .map {
                    AppMetrics.buildTriggerDurationSeconds?.time(since: start)
                }
        case let .packageId(id, force):
            logger.info("Triggering builds (id: \(id)) ...")
            return triggerBuilds(on: database,
                                 client: client,
                                 logger: logger,
                                 packages: [id],
                                 force: force)
                .map {
                    AppMetrics.buildTriggerDurationSeconds?.time(since: start)
                }
    }
}


/// Main build trigger function for a set of package ids. Respects the global override switch, the downscaling factor, and
/// checks against current pipeline limit.
/// - Parameters:
///   - database: `Database` handle used for database access
///   - client: `Client` used for http request
///   - logger: `Logger` used for logging
///   - packages: list of `Package.Id`s to trigger
///   - force: do not check pipeline capacity and ignore downscaling
/// - Returns: `EventLoopFuture<Void>` future
func triggerBuilds(on database: Database,
                   client: Client,
                   logger: Logger,
                   packages: [Package.Id],
                   force: Bool = false) -> EventLoopFuture<Void> {
    guard Current.allowBuildTriggers() else {
        logger.info("Build trigger override switch OFF - no builds are being triggered")
        return database.eventLoop.future()
    }

    guard !force else {
        return packages.map {
            findMissingBuilds(database, packageId: $0).flatMap {
                triggerBuildsUnchecked(on: database, client: client, logger: logger, triggers: $0) }
        }
        .flatten(on: database.eventLoop)
    }

    guard Current.random(0...1) < Current.buildTriggerDownscaling() else {
        logger.info("Build trigger downscaling in effect - skipping builds")
        return database.eventLoop.future()
    }

    return Current.getStatusCount(client, .pending)
        .and(Current.getStatusCount(client, .running))
        .flatMap { (pendingJobs, runningJobs) in
            AppMetrics.buildPendingJobsCount?.set(pendingJobs)
            AppMetrics.buildRunningJobsCount?.set(runningJobs)
            var newJobs = 0
            return packages.map { pkgId in
                // check if we have capacity to schedule more builds before querying for builds
                guard pendingJobs + newJobs < Current.gitlabPipelineLimit() else {
                    logger.info("too many pending pipelines (\(pendingJobs))")
                    return database.eventLoop.future()
                }
                logger.info("Finding missing builds for package id: \(pkgId)")
                return findMissingBuilds(database, packageId: pkgId)
                    .flatMap { triggers in
                        guard pendingJobs + newJobs < Current.gitlabPipelineLimit() else {
                            logger.info("too many pending pipelines (\(pendingJobs))")
                            return database.eventLoop.future()
                        }
                        newJobs += triggers.count
                        return triggerBuildsUnchecked(on: database,
                                                      client: client,
                                                      logger: logger,
                                                      triggers: triggers) }
            }
            .flatten(on: database.eventLoop)
        }
        .flatMap { trimBuilds(on: database) }
        .map {
            AppMetrics.buildTrimCount?.inc($0)
        }
}



/// Trigger builds without checking the pipeline limit. This is the low level trigger function.
/// - Parameters:
///   - database: `Database` handle used for database access
///   - client: `Client` used for http request
///   - logger: `Logger` used for logging
///   - triggers: trigger information for builds to trigger
/// - Returns: `EventLoopFuture<Void>` future
func triggerBuildsUnchecked(on database: Database,
                            client: Client,
                            logger: Logger,
                            triggers: [BuildTriggerInfo]) -> EventLoopFuture<Void> {
    triggers.flatMap { trigger -> [EventLoopFuture<Void>] in
        logger.info("Triggering \(trigger.pairs.count) builds for package name: \(trigger.packageName), ref: \(trigger.reference)")
        return trigger.pairs.map { pair in
            AppMetrics.buildTriggerCount?.inc(1, .init(pair.platform, pair.swiftVersion))
            return Build.trigger(database: database,
                          client: client,
                          platform: pair.platform,
                          swiftVersion: pair.swiftVersion,
                          versionId: trigger.versionId)
                .flatMap { response in
                    Build(versionId: trigger.versionId,
                          jobUrl: response.webUrl,
                          platform: pair.platform,
                          status: .triggered,
                          swiftVersion: pair.swiftVersion)
                        .create(on: database)
                }
        }
    }
    .flatten(on: database.eventLoop)
}


func fetchBuildCandidates(_ database: Database) -> EventLoopFuture<[Package.Id]> {
    guard let db = database as? SQLDatabase else {
        fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
    }

    struct Row: Decodable {
        var packageId: Package.Id

        enum CodingKeys: String, CodingKey {
            case packageId = "package_id"
        }
    }

    let expectedBuildCount = BuildPair.all.count

    return db.raw("""
            SELECT package_id, min(created_at) FROM (
                SELECT v.package_id, v.latest, MIN(v.created_at) created_at
                FROM versions v
                LEFT JOIN builds b ON b.version_id = v.id
                WHERE v.latest IS NOT NULL
                GROUP BY v.package_id, v.latest
                HAVING COUNT(*) < \(bind: expectedBuildCount)
            ) AS t
            GROUP BY package_id
            ORDER BY MIN(created_at)
            """)
        .all(decoding: Row.self)
        .mapEach(\.packageId)
}


struct BuildPair {
    var platform: Build.Platform
    var swiftVersion: SwiftVersion

    init(_ platform: Build.Platform, _ swiftVersion: SwiftVersion) {
        self.platform = platform
        self.swiftVersion = swiftVersion
    }

    static let all: [Self] = {
        Build.Platform.allActive.flatMap { platform in
            SwiftVersion.allActive.compactMap { swiftVersion in
                // skip invalid combinations
                // ARM builds require Swift 5.3 or higher
                guard !platform.isArm || swiftVersion >= .init(5, 3, 0) else { return nil }
                return BuildPair(platform, swiftVersion)
            }
        }
    }()
}


extension BuildPair: Equatable, Hashable {
    static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.platform == rhs.platform
            && lhs.swiftVersion.isCompatible(with: rhs.swiftVersion)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(platform)
        hasher.combine(SwiftVersion(swiftVersion.major, swiftVersion.minor, 0))
    }
}


struct BuildTriggerInfo: Equatable {
    var versionId: Version.Id
    var pairs: Set<BuildPair>
    // non-essential fields, used for logging
    var packageName: String?
    var reference: Reference?

    init?(versionId: Version.Id,
         pairs: Set<BuildPair>,
         packageName: String? = nil,
         reference: Reference? = nil) {
        guard !pairs.isEmpty else { return nil }
        self.versionId = versionId
        self.pairs = pairs
        self.packageName = packageName
        self.reference = reference
    }
}


func missingPairs(existing: [BuildPair]) -> Set<BuildPair> {
     Set(BuildPair.all).subtracting(Set(existing))
 }


func findMissingBuilds(_ database: Database,
                       packageId: Package.Id) -> EventLoopFuture<[BuildTriggerInfo]> {
    let versions = Version.query(on: database)
        .with(\.$builds)
        .filter(\.$package.$id == packageId)
        .filter(\.$latest != nil)
        .all()

    return versions.mapEachCompact { v in
        guard let versionId = v.id else { return nil }
        let existing = v.builds.map { BuildPair($0.platform, $0.swiftVersion) }
        return BuildTriggerInfo(versionId: versionId,
                                pairs: missingPairs(existing: existing),
                                packageName: v.packageName,
                                reference: v.reference)
    }
}


func trimBuilds(on database: Database) -> EventLoopFuture<Int> {
    guard let db = database as? SQLDatabase else {
        fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
    }

    struct Row: Decodable {
        var id: Build.Id
    }

    return db.raw("""
        DELETE
        FROM builds b
        USING versions v
        WHERE b.version_id = v.id
        AND (
          v.latest is null
          OR (
            b.status IN ('\(raw: Build.Status.triggered.rawValue)', '\(raw: Build.Status.infrastructureError.rawValue)')
            AND b.created_at < NOW() - INTERVAL '\(raw: String(Constants.trimBuildsGracePeriod.inHours)) hours'
          )
        )
        RETURNING b.id
        """)
        .all(decoding: Row.self)
        .map { $0.count }
}
