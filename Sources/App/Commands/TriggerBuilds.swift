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
        let logger = context.application.logger

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
            return fetchBuildCandidates(database, limit: limit)
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
        .flatMap { pendingJobs in
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
    triggers.map { trigger -> EventLoopFuture<Void> in
        logger.info("Triggering \(trigger.pairs.count) builds for version id: \(trigger.versionId)")
        return trigger.pairs.map { pair in
            Build.trigger(database: database,
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
                .transform(to: ())
        }
        .flatten(on: database.eventLoop)
    }
    .flatten(on: database.eventLoop)
}


func fetchBuildCandidates(_ database: Database,
                          limit: Int) -> EventLoopFuture<[Package.Id]> {
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
            SELECT package_id, min(updated_at) FROM (
                SELECT v.package_id, v.latest, MIN(v.updated_at) updated_at
                FROM versions v
                LEFT JOIN builds b ON b.version_id = v.id
                WHERE v.latest IS NOT NULL
                GROUP BY v.package_id, v.latest
                HAVING COUNT(*) < \(bind: expectedBuildCount)
            ) AS t
            GROUP BY package_id
            ORDER BY MIN(updated_at)
            LIMIT \(bind: limit)
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

    init(_ versionId: Version.Id, _ pairs: Set<BuildPair>) {
        self.versionId = versionId
        self.pairs = pairs
    }
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
        let pairs = Set(BuildPair.all).subtracting(Set(existing))
        return BuildTriggerInfo(versionId, pairs)
    }
}


func trimBuilds(on database: Database) -> EventLoopFuture<Void> {
    guard let db = database as? SQLDatabase else {
        fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
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
        """).run()
}
