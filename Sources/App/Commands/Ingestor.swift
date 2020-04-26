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

        // for selected packages:
        // - fetch meta data
        // - create/update repository

        let db = context.application.db
        let client = context.application.client

        let metaData = Package.query(on: db)
            .ingestionBatch(limit: limit)
            .flatMapEachThrowing { try Github.fetchRepository(client: client,
                                                              package: $0).and(value: $0) }
            .flatMap { $0.flatten(on: db.eventLoop) }
        let updates = metaData
            .flatMapEachThrowing { (ghRepo, pkg) -> EventLoopFuture<Void> in
                try insertOrUpdateRepository(on: db, for: pkg, metadata: ghRepo)
        }
        .flatMap { $0.flatten(on: db.eventLoop) }

        try updates.wait()
    }

}


func insertOrUpdateRepository(on db: Database, for package: Package, metadata: Github.Metadata) throws -> EventLoopFuture<Void> {
    // TODO: fetch existing
    try Repository(package: package, metadata: metadata)
        .create(on: db)
}


