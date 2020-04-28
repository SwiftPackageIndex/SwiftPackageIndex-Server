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


// TODO: Move to Package.setStatus or somewhere
func setStatus(_ database: Database, id: Package.Id?, status: Status) -> EventLoopFuture<Void> {
    Package.find(id, on: database).flatMap { pkg -> EventLoopFuture<Void> in
        guard let pkg = pkg else { return database.eventLoop.makeSucceededFuture(()) }
        pkg.status = status
        return pkg.save(on: database)
    }
}


func ingest(client: Client, database: Database, limit: Int) -> EventLoopFuture<Void> {
    fetchMetadata(client: client, database: database, limit: limit)
        .flatMapEachThrowing { result in
            do {
                let (pkg, md) = try result.get()
                return try insertOrUpdateRepository(on: database, for: pkg, metadata: md)
                    .flatMap {
                        pkg.status = .ok
                        return pkg.save(on: database)
                    }
            } catch let AppError.invalidPackageUrl(id, url) {
                database.logger.error("\(#function): \(AppError.invalidPackageUrl(id, url).localizedDescription)")
                return setStatus(database, id: id, status: .invalidUrl)
            } catch let AppError.metadataRequestFailed(id, status, uri) {
                database.logger.error("\(#function): \(AppError.metadataRequestFailed(id, status, uri).localizedDescription)")
                return setStatus(database, id: id, status: .metadataRequestFailed)
            } catch let AppError.genericError(id, msg) {
                database.logger.error("\(#function): \(AppError.genericError(id, msg))")
                return setStatus(database, id: id, status: .ingestionFailed)
            } catch {
                // TODO: log somewhere more actionable - table or online service
                database.logger.error("\(#function): \(error.localizedDescription)")
                return database.eventLoop.makeSucceededFuture(())
            }
        }
        .flatMap { .andAllComplete($0, on: database.eventLoop) }
}


func fetchMetadata(client: Client, database: Database, limit: Int) -> EventLoopFuture<[Result<(Package, Github.Metadata), Error>]> {
    Package.query(on: database)
        .ingestionBatch(limit: limit)
        .flatMapEach(on: database.eventLoop) { pkg in
            do {
                return try Current.fetchMetadata(client, pkg)
                    .map { .success((pkg, $0)) }
                    .flatMapErrorThrowing { .failure($0) }
            } catch {
                return database.eventLoop.makeSucceededFuture(.failure(error))
            }
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
                        AppError.genericError(package.id,
                                              "Failed to create Repository for \(package.url)")
                    )
                }
            }
        }
}


