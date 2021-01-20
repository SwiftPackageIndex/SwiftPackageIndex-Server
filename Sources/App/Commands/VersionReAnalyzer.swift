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
                                     packages: $0) }
}


func reAnalyzeVersions(client: Client,
                       database: Database,
                       logger: Logger,
                       threadPool: NIOThreadPool,
                       packages: [Package]) -> EventLoopFuture<Void> {
    // TODO: implement
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
