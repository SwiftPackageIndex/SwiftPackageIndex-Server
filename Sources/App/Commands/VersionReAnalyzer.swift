import Vapor
import Fluent


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


/// Re-analyze outdated version for the given list of `Package`s.
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
    // Pick essentials parts of comapanion function `analyze`
    // We don't refresh checkouts, because these are being freshed in `analyze`
    // and would race unnecessarily if we also tried to refresh them here.
    //
    // On that note: care should be taken to ensure `reAnalyzeVersions` operates
    // on a set of versions that is distinct from those `analyze` updates, to
    // avoid data races.
    //
    // Since `reAnalyzeVersions` only updates existing versions, this will be the
    // case by design, as `analyze` will only add or remove versions, ignoring
    // existing ones.
    database.eventLoop.future()
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
