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
        @Option(name: "id")
        var id: UUID?
    }

    var help: String { "Trigger package builds" }

    enum Parameter {
        case limit(Int)
        case id(UUID, force: Bool)
    }

    func run(using context: CommandContext, signature: Signature) throws {
        let limit = signature.limit ?? defaultLimit
        let force = signature.force
        let logger = Logger(component: "trigger-builds")

        let parameter: Parameter
        if let id = signature.id {
            logger.info("Triggering builds (id: \(id)) ...")
            parameter = .id(id, force: force)
        } else {
            if force {
                logger.warning("--force has no effect when used with --limit")
            }
            logger.info("Triggering builds (limit: \(limit)) ...")
            parameter = .limit(limit)
        }
        try triggerBuilds(on: context.application.db,
                          client: context.application.client,
                          logger: logger,
                          parameter: parameter).wait()
        try AppMetrics.push(client: context.application.client,
                            logger: context.application.logger,
                            jobName: "trigger-builds").wait()
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
                   parameter: TriggerBuildsCommand.Parameter) -> EventLoopFuture<Void> {
    switch parameter {
        case .limit(let limit):
            return fetchBuildCandidates(database)
                .map { candidates in
                    AppMetrics.buildCandidatesCount?.set(candidates.count)
                    return Array(candidates.prefix(limit))
                }
                .flatMap { triggerBuilds(on: database,
                                         client: client,
                                         logger: logger,
                                         packages: $0) }
        case let .id(id, force):
            return triggerBuilds(on: database,
                                 client: client,
                                 logger: logger,
                                 packages: [id],
                                 force: force)
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
            AppMetrics.buildTrimTotal?.inc($0)
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
            AppMetrics.buildTriggerTotal?.inc(1, .init(pair.platform, pair.swiftVersion))
            return Build.trigger(database: database,
                          client: client,
                          platform: pair.platform,
                          swiftVersion: pair.swiftVersion,
                          versionId: trigger.versionId)
                .flatMap { _ in
                    Build(versionId: trigger.versionId,
                          platform: pair.platform,
                          status: .pending,
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
                JOIN packages p ON v.package_id = p.id
                -- select versions, that are
                WHERE v.latest IS NOT NULL
                  AND (
                    -- either tags
                    v.reference->'tag' IS NOT NULL
                    OR
                    -- or branches
                    (
                      v.reference->'branch' IS NOT NULL
                      AND (
                        -- which are more than interval T old
                        v.created_at < NOW() - INTERVAL '\(raw: String(Constants.branchBuildDeadTime)) hours'
                        -- or whose package has been created within interval T
                        OR p.created_at >= NOW() - INTERVAL '\(raw: String(Constants.branchBuildDeadTime)) hours'
                      )
                    )
                  )
                GROUP BY v.package_id, v.latest
                HAVING COUNT(*) < \(bind: expectedBuildCount)
            ) AS t
            GROUP BY package_id
            ORDER BY MIN(created_at)
            """)
        .all(decoding: Row.self)
        .mapEach(\.packageId)
}


struct BuildPair: Equatable, Hashable {
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


struct BuildTriggerInfo: Equatable {
    var versionId: Version.Id
    var pairs: Set<BuildPair>
    // non-essential fields, used for logging
    var packageName: String?
    var reference: Reference?

    init(versionId: Version.Id,
         pairs: Set<BuildPair>,
         packageName: String? = nil,
         reference: Reference? = nil) {
        self.versionId = versionId
        self.pairs = pairs
        self.packageName = packageName
        self.reference = reference
    }
}


func findMissingBuilds(_ database: Database,
                       packageId: Package.Id) -> EventLoopFuture<[BuildTriggerInfo]> {
    let cutOffDate = Current.date().addingTimeInterval(-TimeInterval(Constants.branchBuildDeadTime*3600))

    let versions = Version.query(on: database)
        .with(\.$builds)
        .with(\.$package)
        .filter(\.$package.$id == packageId)
        .filter(\.$latest != nil)
        .all()
        .mapEachCompact { version -> Version? in
            // filter branch versions against branchBuildDeadTime client side,
            // because it's not clear how to write
            // v.reference->'tag' IS NOT NULL
            // in Fluent - and the select isn't huge
            guard
                let reference = version.reference,
                let packageCreatedAt = version.package.createdAt,
                let versionCreatedAt = version.createdAt else {
                return nil
            }
            if reference.isTag { return version }
            let isNewPackage = packageCreatedAt >= cutOffDate
            let isOldVersion = versionCreatedAt < cutOffDate
            return isNewPackage || isOldVersion
                ? version
                : nil
        }

    return versions.mapEachCompact { v in
        guard let versionId = v.id else { return nil }
        let existing = v.builds.map { BuildPair($0.platform, $0.swiftVersion) }
        let pairs = Set(BuildPair.all).subtracting(Set(existing))
        return BuildTriggerInfo(versionId: versionId,
                                pairs: pairs,
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
            OR
            (b.status = 'pending' AND b.created_at < NOW() - INTERVAL '\(bind: Constants.trimBuildsGracePeriod) hours')
        )
        RETURNING b.id
        """)
        .all(decoding: Row.self)
        .map { $0.count }
}
