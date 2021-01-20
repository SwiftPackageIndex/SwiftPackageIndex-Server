import Vapor
import Fluent


/// Re-analyze outdated versions.
/// - Parameters:
///   - client: `Client` object
///   - database: `Database` object
///   - logger: `Logger` object
///   - threadPool: `NIOThreadPool` (for running shell commands)
///   - versionsLastUpdatedBefore: `Date` cut-off for versions to update
///   - packages: packages to be analysed
/// - Returns: future
func reAnalyzeVersions(client: Client,
                       database: Database,
                       logger: Logger,
                       threadPool: NIOThreadPool,
                       versionsLastUpdatedBefore cutOffDate: Date,
                       limit: Int) -> EventLoopFuture<Void> {
    Package.fetchReAnalysisCandidates(database,
                                      versionsLastUpdatedBefore: cutOffDate,
                                      limit: limit)
        .flatMap { reAnalyzeVersions(client: client,
                                     database: database,
                                     logger: logger,
                                     threadPool: threadPool,
                                     versionsLastUpdatedBefore: cutOffDate,
                                     packages: $0) }
}


/// Re-analyze outdated versions for the given list of `Package`s.
/// - Parameters:
///   - client: `Client` object
///   - database: `Database` object
///   - logger: `Logger` object
///   - threadPool: `NIOThreadPool` (for running shell commands)
///   - versionsLastUpdatedBefore: `Date` cut-off for versions to update
///   - packages: packages to be analysed
/// - Returns: future
func reAnalyzeVersions(client: Client,
                       database: Database,
                       logger: Logger,
                       threadPool: NIOThreadPool,
                       versionsLastUpdatedBefore cutOffDate: Date,
                       packages: [Package]) -> EventLoopFuture<Void> {
    // Pick essentials parts of companion function `analyze` and run the for
    // re-analysis.
    //
    // We don't refresh checkouts, because these are being freshed in `analyze`
    // and would race unnecessarily if we also tried to refresh them here.
    //
    // Care should be taken to ensure `reAnalyzeVersions` operates on a
    // set of versions that is distinct from those `analyze` updates, to
    // avoid data races.
    //
    // Since `reAnalyzeVersions` only updates existing versions, this will be the
    // case by design, as `analyze` will only add or remove versions, ignoring
    // existing ones.

    database.transaction { tx in
        getExistingVersions(client: client,
                            logger: logger,
                            threadPool: threadPool,
                            transaction: tx,
                            packages: packages)
            // FIXME: this should be part of it
            //  .flatMap { mergeReleaseInfo(on: tx, packageDeltas: $0) }
            .map { getManifests(logger: logger, packageAndVersions: $0) }
            .flatMap { updateVersions(on: tx, packageResults: $0) }
            .flatMap { updateProducts(on: tx, packageResults: $0) }
            .flatMap { updateTargets(on: tx, packageResults: $0) }
    }
    .transform(to: ())
}


func getExistingVersions(client: Client,
                         logger: Logger,
                         threadPool: NIOThreadPool,
                         transaction: Database,
                         packages: [Package]) -> EventLoopFuture<[Result<(Package, [Version]), Error>]> {
    EventLoopFuture.whenAllComplete(
        packages.map { pkg in
            diffVersions(client: client,
                         logger: logger,
                         threadPool: threadPool,
                         transaction: transaction,
                         package: pkg)
                .map { (pkg, $0.toKeep) }
        },
        on: transaction.eventLoop
    )
}


// TODO: replace createProduct with this
func updateProducts(on database: Database,
                    packageResults: [Result<(Package, [(Version, Manifest)]), Error>]) -> EventLoopFuture<[Result<(Package, [(Version, Manifest)]), Error>]> {
    packageResults.whenAllComplete(on: database.eventLoop) { (pkg, versionsAndManifests) in
        EventLoopFuture.andAllComplete(
            versionsAndManifests.map { version, manifest in
                Product.query(on: database)
                    .filter(\.$version.$id == version.id!)
                    .delete()
                    .flatMap {
                        createProducts(on: database, version: version, manifest: manifest)
                    }
            },
            on: database.eventLoop
        )
        .transform(to: (pkg, versionsAndManifests))
    }
}


// TODO: replace createTargets with this
func updateTargets(on database: Database,
                   packageResults: [Result<(Package, [(Version, Manifest)]), Error>]) -> EventLoopFuture<[Result<(Package, [(Version, Manifest)]), Error>]> {
    packageResults.whenAllComplete(on: database.eventLoop) { (pkg, versionsAndManifests) in
        EventLoopFuture.andAllComplete(
            versionsAndManifests.map { version, manifest in
                Target.query(on: database)
                    .filter(\.$version.$id == version.id!)
                    .delete()
                    .flatMap {
                        createTargets(on: database, version: version, manifest: manifest)
                    }
            },
            on: database.eventLoop
        )
        .transform(to: (pkg, versionsAndManifests))
    }
}


extension Package {
    static func fetchReAnalysisCandidates(
        _ database: Database,
        versionsLastUpdatedBefore cutOffDate: Date,
        limit: Int) -> EventLoopFuture<[Package]> {
        Package.query(on: database)
            .with(\.$repositories)
            .join(Version.self, on: \Package.$id == \Version.$package.$id)
            .filter(Version.self, \.$updatedAt < cutOffDate)
            .fields(for: Package.self)
            .unique()
            .sort(\.$updatedAt)
            .limit(limit)
            .all()
    }
}
