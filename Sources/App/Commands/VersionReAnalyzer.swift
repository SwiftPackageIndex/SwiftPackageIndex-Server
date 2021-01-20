import Vapor
import Fluent


func reAnalyzeVersions(client: Client,
                       database: Database,
                       logger: Logger,
                       threadPool: NIOThreadPool,
                       limit: Int) -> EventLoopFuture<Void> {
    Package.fetchReAnalysisCandidates(database, limit: limit)
        .flatMap { analyze(client: client,
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
    static func fetchReAnalysisCandidates(_ database: Database,
                                          limit: Int) -> EventLoopFuture<[Package]> {
        // TODO: update query
        Package.query(on: database)
            .with(\.$repositories)
            .sort(.sql(raw: "status != 'new'"))
            .sort(\.$updatedAt)
            .limit(limit)
            .all()
    }
}
