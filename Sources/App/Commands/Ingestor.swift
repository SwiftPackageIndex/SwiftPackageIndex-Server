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
        let request = ingest(client: context.application.client,
                             database: context.application.db,
                             limit: limit)
        context.console.info("Processing ...", newLine: true)
        try request.wait()
    }

}


func ingest(client: Client, database: Database, limit: Int) -> EventLoopFuture<Void> {
    fetchMetadata(client: client, database: database, limit: limit)
        .flatMapEachThrowing { result in
            // TODO: sas 2020-04-28: this body can probably be written more concisely
            // There must be a way to pick out the success and do a single error handler
            // I was hoping to tack on a flatMapError but that only work on the pipeline
            // as a whole.
            switch result {
                case let .success((pkg, md)):
                    do {
                        return try insertOrUpdateRepository(on: database, for: pkg, metadata: md)
                            .flatMap { pkg.update(on: database) }  // mark package as updated
                    } catch {
                        // TODO: log somewhere more actionable - table or online service
                        database.logger.error("ingest: \(error.localizedDescription)")
                }
                case let .failure(error):
                    // TODO: log somewhere more actionable - table or online service
                    database.logger.error("ingest: \(error.localizedDescription)")
            }
            return database.eventLoop.makeSucceededFuture(())
    }
    .flatMap { .andAllComplete($0, on: database.eventLoop) }
}


func fetchMetadata(client: Client, database: Database, limit: Int) -> EventLoopFuture<[Result<(Package, Github.Metadata), Error>]> {
    Package.query(on: database)
        .ingestionBatch(limit: limit)
        .flatMapEach(on: database.eventLoop) { pkg in
            do {
                return try
                    database.eventLoop.makeSucceededFuture(pkg)
                        .and(Current.fetchMetadata(client, pkg))
                        .map {
                            Result<(Package, Github.Metadata), Error>.success($0)}
            }
            catch { return database.eventLoop.makeSucceededFuture(Result.failure(error)) }
    }
}


func insertOrUpdateRepository(on db: Database, for package: Package, metadata: Github.Metadata) throws -> EventLoopFuture<Void> {
    Repository.query(on: db)
        .filter(try \.$package.$id == package.requireID())
        .first()
        .flatMap { repo -> EventLoopFuture<Void> in
            if let repo = repo {
                repo.defaultBranch = metadata.defaultBranch
                repo.description = metadata.description
                repo.forks = metadata.forksCount
                repo.license = metadata.license?.key
                repo.stars = metadata.stargazersCount
                // TODO: find and assign parent repo
                return repo.save(on: db)
            } else {
                do {
                    return try Repository(package: package, metadata: metadata)
                        .save(on: db)
                } catch {
                    return db.eventLoop.makeFailedFuture(
                        AppError.genericError("Failed to create Repository for \(package.url)")
                    )
                }
            }
        }
}


