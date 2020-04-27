import Vapor
import Fluent


struct IngestorCommand: Command {
    let defaultLimit = 2

    struct Signature: CommandSignature {
        @Option(name: "limit", short: "l")
        var limit: Int?
    }

    var help: String {
        "Ingests packages"
    }

    func run(using context: CommandContext, signature: Signature) throws {
        let limit = signature.limit ?? defaultLimit
        context.console.print("Ingesting (limit: \(limit)) ...")
        let request = try ingest(client: context.application.client,
                                 database: context.application.db,
                                 limit: limit)
        try request.wait()
    }

}


func ingest(client: Client, database: Database, limit: Int) throws -> EventLoopFuture<Void> {
    let metaData = Package.query(on: database)
        .ingestionBatch(limit: limit)
        .flatMapEachThrowing { try Current.fetchRepository(client, $0).and(value: $0) }
        .flatMap { $0.flatten(on: database.eventLoop) }
    return metaData
        .flatMapEachThrowing { (ghRepo, pkg) -> EventLoopFuture<Void> in
            try insertOrUpdateRepository(on: database, for: pkg, metadata: ghRepo)
    }
    .flatMap { $0.flatten(on: database.eventLoop) }
}


func insertOrUpdateRepository(on db: Database, for package: Package, metadata: Github.Metadata) throws -> EventLoopFuture<Void> {
    Repository.query(on: db)
        .filter(try \.$package.$id == package.requireID())
        .first()
        .flatMapThrowing { repo -> EventLoopFuture<Void> in
            if let repo = repo {
                // TODO: update
                return repo.save(on: db)
            } else {
                return try Repository(package: package, metadata: metadata)
                    .create(on: db)
            }
    }.transform(to: ())
}


