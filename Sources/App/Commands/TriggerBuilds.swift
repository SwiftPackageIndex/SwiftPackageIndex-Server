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
import SQLKit
import Vapor
@preconcurrency import SPIManifest


struct TriggerBuildsCommand: AsyncCommand {
    let defaultLimit = 1

    struct Signature: CommandSignature {
        @Option(name: "limit", short: "l")
        var limit: Int?

        @Flag(name: "force", short: "f", help: "override pipeline capacity check and downscaling (--id only)")
        var force: Bool

        @Flag(name: "is-doc-build", help: "signal if a build is a doc build, giving it a more generous build timeout")
        var isDocBuild: Bool

        @Option(name: "package-id", short: "i")
        var packageId: Package.Id?

        @Option(name: "platform", short: "p")
        var platform: Build.Platform?

        @Option(name: "swift-version", short: "s")
        var swiftVersion: SwiftVersion?

        @Option(name: "version-id", short: "v")
        var versionId: Version.Id?
    }

    var help: String { "Trigger package builds" }

    enum Mode {
        case limit(Int)
        case packageId(Package.Id, force: Bool)
        case triggerInfo(Version.Id, BuildPair, isDocBuild: Bool)
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        prepareDependencies {
            $0.logger = Logger(component: "trigger-builds")
        }
        @Dependency(\.logger) var logger

        Self.resetMetrics()

        let mode: Mode
        switch (signature.limit, signature.packageId, signature.versionId) {
            case let (.some(limit), .none, .none):
                mode = .limit(limit)

            case let (.none, .some(packageId), .none):
                mode = .packageId(packageId, force: signature.force)

            case let (.none, .none, .some(versionId)):
                guard let platform = signature.platform,
                      let swiftVersion = signature.swiftVersion else {
                    printUsage(using: context)
                    return
                }
                let buildPair = BuildPair(platform, swiftVersion)
                mode = .triggerInfo(versionId, buildPair, isDocBuild: signature.isDocBuild)

            case (.none, .none, .none):
                mode = .limit(defaultLimit)

            default:
                printUsage(using: context)
                return
        }

        do {
            try await triggerBuilds(on: context.application.db, mode: mode)
        } catch {
            logger.critical("\(error)")
        }

        do {
            try await AppMetrics.push(client: context.application.client,
                                      jobName: "trigger-builds")
        } catch {
            logger.warning("\(error)")
        }
    }

    func printUsage(using context: CommandContext) {
        var context = context
        outputHelp(using: &context)
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
///   - parameter: `BuildTriggerCommand.Parameter` holding either a list of package ids
///   or a fetch limit for candidate selection.
func triggerBuilds(on database: Database, mode: TriggerBuildsCommand.Mode) async throws {
    @Dependency(\.environment) var environment
    @Dependency(\.logger) var logger

    let start = DispatchTime.now().uptimeNanoseconds

    switch mode {
        case .limit(let limit):
            logger.info("Triggering builds (limit: \(limit)) ...")

            let withLatestSwiftVersion = environment.buildTriggerCandidatesWithLatestSwiftVersion
            let candidates = try await fetchBuildCandidates(database,
                                                            withLatestSwiftVersion: withLatestSwiftVersion)
            AppMetrics.buildCandidatesCount?.set(candidates.count)

            let limitedCandidates = Array(candidates.prefix(limit))
            try await triggerBuilds(on: database, packages: limitedCandidates)
            AppMetrics.buildTriggerDurationSeconds?.time(since: start)

        case let .packageId(id, force):
            logger.info("Triggering builds (packageID: \(id)) ...")
            try await triggerBuilds(on: database,
                                    packages: [id],
                                    force: force)
            AppMetrics.buildTriggerDurationSeconds?.time(since: start)

        case let .triggerInfo(versionId, buildPair, isDocBuild):
            logger.info("Triggering builds (versionID: \(versionId), \(buildPair)) ...")
            guard let trigger = BuildTriggerInfo(versionId: versionId,
                                                 buildPairs: [buildPair],
                                                 docPairs: isDocBuild ? [buildPair] : []) else {
                logger.error("Failed to create trigger.")
                return
            }
            try await triggerBuildsUnchecked(on: database, triggers: [trigger])

    }
}


/// Main build trigger function for a set of package ids. Respects the global override switch, the downscaling factor, and
/// checks against current pipeline limit.
/// - Parameters:
///   - database: `Database` handle used for database access
///   - client: `Client` used for http request
///   - packages: list of `Package.Id`s to trigger
///   - force: do not check pipeline capacity and ignore downscaling
func triggerBuilds(on database: Database,
                   packages: [Package.Id],
                   force: Bool = false) async throws {
    @Dependency(\.environment) var environment
    @Dependency(\.buildSystem) var buildSystem
    @Dependency(\.logger) var logger

    guard environment.allowBuildTriggers() else {
        logger.info("Build trigger override switch OFF - no builds are being triggered")
        return
    }

    guard !force else {
        return await withThrowingTaskGroup(of: Void.self) { group in
            for package in packages {
                group.addTask {
                    let triggerInfo = try await findMissingBuilds(database, packageId: package)
                    try await triggerBuildsUnchecked(on: database, triggers: triggerInfo)
                }
            }
        }
    }

    let getStatusCount = buildSystem.getStatusCount
    async let pendingJobsTask = getStatusCount(.pending)
    async let runningJobsTask = getStatusCount(.running)
    let pendingJobs = try await pendingJobsTask
    let runningJobs = try await runningJobsTask

    AppMetrics.buildPendingJobsCount?.set(pendingJobs)
    AppMetrics.buildRunningJobsCount?.set(runningJobs)

    let newJobs = ActorIsolated(0)
    let gitlabPipelineLimit = environment.gitlabPipelineLimit

    await withThrowingTaskGroup(of: Void.self) { group in
        for pkgId in packages {
            let allowListed = environment.buildTriggerAllowList().contains(pkgId)
            guard allowListed || environment.buildTriggerDownscalingAccepted else {
                logger.info("Build trigger downscaling in effect - skipping builds")
                continue
            }

            group.addTask { [logger] in
                // check if we have capacity to schedule more builds before querying for builds
                var newJobCount = await newJobs.value
                guard pendingJobs + newJobCount < gitlabPipelineLimit() else {
                    logger.info("too many pending pipelines (\(pendingJobs + newJobCount))")
                    return
                }

                logger.info("Finding missing builds for package id: \(pkgId)")
                let triggers = try await findMissingBuilds(database, packageId: pkgId)

                newJobCount = await newJobs.value
                guard pendingJobs + newJobCount < gitlabPipelineLimit() else {
                    logger.info("too many pending pipelines (\(pendingJobs + newJobCount))")
                    return
                }

                let triggeredJobCount = triggers.reduce(0) { $0 + $1.buildPairs.count }
                await newJobs.withValue { $0 += triggeredJobCount }

                try await triggerBuildsUnchecked(on: database, triggers: triggers)
            }
        }
    }
    let deleted = try await trimBuilds(on: database)

    AppMetrics.buildTrimCount?.inc(deleted)
}



/// Trigger builds without checking the pipeline limit. This is the low level trigger function.
/// - Parameters:
///   - database: `Database` handle used for database access
///   - client: `Client` used for http request
///   - triggers: trigger information for builds to trigger
func triggerBuildsUnchecked(on database: Database, triggers: [BuildTriggerInfo]) async throws {
    @Dependency(\.logger) var logger
    await withThrowingTaskGroup(of: Void.self) { group in
        for trigger in triggers {
            if let packageName = trigger.packageName, let reference = trigger.reference {
                logger.info("Triggering \(pluralizedCount: trigger.buildPairs.count, singular: "build") for package name: \(packageName), ref: \(reference)")
            } else {
                logger.info("Triggering \(pluralizedCount: trigger.buildPairs.count, singular: "build") for version ID: \(trigger.versionId)")
            }

            for pair in trigger.buildPairs {
                group.addTask {
                    AppMetrics.buildTriggerCount?.inc(1, .buildTriggerLabels(pair))
                    let buildId = Build.Id()

                    let response = try await Build.trigger(database: database,
                                                           buildId: buildId,
                                                           isDocBuild: trigger.docPairs.contains(pair),
                                                           platform: pair.platform,
                                                           swiftVersion: pair.swiftVersion,
                                                           versionId: trigger.versionId)
                    guard [HTTPStatus.ok, .created].contains(response.status),
                          let jobUrl = response.webUrl
                    else { return }

                    do {
                        try await Build(id: buildId,
                                        versionId: trigger.versionId,
                                        jobUrl: jobUrl,
                                        platform: pair.platform,
                                        status: .triggered,
                                        swiftVersion: pair.swiftVersion)
                        .create(on: database)
                    } catch let error as PSQLError where error.isUniqueViolation {
                        if let oldBuild = try await Build.query(on: database,
                                                                platform: pair.platform,
                                                                swiftVersion: pair.swiftVersion,
                                                                versionId: trigger.versionId) {
                            // Fluent doesn't allow modification of the buildId of an existing
                            // record, therefore we need to delete + create.
                            let newBuild = Build(id: buildId,
                                                 versionId: trigger.versionId,
                                                 buildCommand: oldBuild.buildCommand,
                                                 jobUrl: jobUrl,
                                                 platform: pair.platform,
                                                 status: .triggered,
                                                 swiftVersion: pair.swiftVersion)
                            try await database.transaction { tx in
                                try await oldBuild.delete(on: tx)
                                try await newBuild.create(on: tx)
                            }
                        }
                    }
                }
            }
        }
    }
}


func fetchBuildCandidates(_ database: Database,
                          withLatestSwiftVersion: Bool = true) async throws -> [Package.Id] {
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
    let expectedBuildCountWithoutLatestSwiftVersion = BuildPair.allExceptLatestSwiftVersion.count

    @Dependency(\.environment) var environment
    let priorityIDs = environment.buildTriggerAllowList()

    let query: SQLQueryString = withLatestSwiftVersion
    ? """
        SELECT package_id, is_prio, min(created_at) FROM (
            SELECT v.package_id,
                   ARRAY[v.package_id] <@ \(bind: priorityIDs) is_prio,
                   v.latest,
                   MIN(v.created_at) created_at
            FROM versions v
            LEFT JOIN builds b ON b.version_id = v.id
            WHERE v.latest IS NOT NULL
            GROUP BY v.package_id, v.latest
            HAVING COUNT(*) < \(bind: expectedBuildCount)
        ) AS t
        GROUP BY package_id, is_prio
        ORDER BY is_prio DESC, MIN(created_at)
        """
    : """
        SELECT package_id, is_prio, min(created_at) FROM (
            SELECT v.package_id,
                   ARRAY[v.package_id] <@ \(bind: priorityIDs) is_prio,
                   v.latest,
                   MIN(v.created_at) created_at
            FROM versions v
            LEFT JOIN builds b ON b.version_id = v.id
                AND NOT (
                  (b.swift_version->'major')::INT = \(bind: SwiftVersion.latest.major)
                  AND (b.swift_version->'minor')::INT = \(bind: SwiftVersion.latest.minor)
                )
            WHERE v.latest IS NOT NULL
            GROUP BY v.package_id, v.latest
            HAVING COUNT(*) < \(bind: expectedBuildCountWithoutLatestSwiftVersion)
        ) AS t
        GROUP BY package_id, is_prio
        ORDER BY is_prio DESC, MIN(created_at)
        """

    return try await db.raw(query)
        .all(decoding: Row.self)
        .map(\.packageId)
}


struct BuildPair {
    var platform: Build.Platform
    var swiftVersion: SwiftVersion

    init(_ platform: Build.Platform, _ swiftVersion: SwiftVersion) {
        self.platform = platform
        self.swiftVersion = swiftVersion
    }

    static let all = Build.Platform.allActive.flatMap { platform in
        SwiftVersion.allActive.compactMap { swiftVersion in
            switch platform {
                case .iOS, .linux, .macosSpm, .macosXcodebuild, .tvOS, .watchOS:
                    return BuildPair(platform, swiftVersion)
                case .visionOS:
                    // visionOS is only available for Swift versions 5.9+
                    return swiftVersion >= .v5_9 ? BuildPair(platform, swiftVersion) : nil
            }
        }
    }

    static let allExceptLatestSwiftVersion = all.filter { $0.swiftVersion != .latest }
}


extension BuildPair: CustomStringConvertible {
    var description: String { "\(platform) / \(swiftVersion)" }
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
    var buildPairs: Set<BuildPair>
    var docPairs: Set<BuildPair>
    // non-essential fields, used for logging
    var packageName: String?
    var reference: Reference?

    init?(versionId: Version.Id,
          buildPairs: Set<BuildPair>,
          docPairs: Set<BuildPair> = .init(),
          packageName: String? = nil,
          reference: Reference? = nil) {
        guard !buildPairs.isEmpty else { return nil }
        self.versionId = versionId
        self.buildPairs = buildPairs
        self.docPairs = docPairs
        self.packageName = packageName
        self.reference = reference
    }
}


func missingPairs(existing: [BuildPair]) -> Set<BuildPair> {
     Set(BuildPair.all).subtracting(Set(existing))
 }


func findMissingBuilds(_ database: Database,
                       packageId: Package.Id) async throws -> [BuildTriggerInfo] {
    let versions = try await Version.query(on: database)
        .filter(\.$package.$id == packageId)
        .filter(\.$latest != nil)
        .field(Version.self, \.$id)
        .field(Version.self, \.$packageName)
        .field(Version.self, \.$reference)
        .field(Version.self, \.$spiManifest)
        .all()
    let builds = try await Build.query(on: database)
        .filter(\.$version.$id ~~ versions.compactMap(\.id))
        .field(Build.self, \.$platform)
        .field(Build.self, \.$swiftVersion)
        .field(Build.self, \.$version.$id)
        .all()

    return versions.compactMap { v in
        guard let versionId = v.id else { return nil }
        let builds = builds.filter { $0.$version.id == versionId }
        let existing = builds.map { BuildPair($0.platform, $0.swiftVersion) }
        return BuildTriggerInfo(versionId: versionId,
                                buildPairs: missingPairs(existing: existing),
                                docPairs: v.spiManifest?.docPairs ?? [],
                                packageName: v.packageName,
                                reference: v.reference)
    }
}


func trimBuilds(on database: Database) async throws -> Int {
    guard let db = database as? SQLDatabase else {
        fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
    }

    struct Row: Decodable {
        var id: Build.Id
    }

    return try await db.raw("""
        DELETE
        FROM builds b
        USING versions v
        WHERE b.version_id = v.id
        AND b.created_at < NOW() - INTERVAL \(literal: "\(Constants.trimBuildsGracePeriod.inHours) hours")
        AND (
          (
            -- significant version: delete only old builds that are triggered or infrastructureError builds
            v.latest IS NOT NULL
            AND
            b.status IN (\(literal: Build.Status.triggered.rawValue), \(literal: Build.Status.infrastructureError.rawValue))
          )
          OR (
            -- non-significant version: delete all old builds
            v.latest is null
          )
        )
        RETURNING b.id
        """)
        .all(decoding: Row.self)
        .count
}
