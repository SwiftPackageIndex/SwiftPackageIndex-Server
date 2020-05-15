import Vapor
import Fluent


struct IngestorCommand: Command {
    let defaultLimit = 1

    struct Signature: CommandSignature {
        @Option(name: "limit", short: "l")
        var limit: Int?
    }

    var help: String { "Run package ingestion (fetching repository metadata)" }

    func run(using context: CommandContext, signature: Signature) throws {
        let limit = signature.limit ?? defaultLimit
        context.console.info("Ingesting (limit: \(limit)) ...")
        let request = ingest(client: context.application.client,
                             database: context.application.db,
                             limit: limit)
        context.console.info("Processing ...", newLine: true)
        try request.wait()
    }

}


func ingest(client: Client, database: Database, limit: Int) -> EventLoopFuture<Void> {
    Package.fetchCandidates(database, for: .ingestion, limit: limit)
        .flatMapEach(on: database.eventLoop) { fetchMetadata(for: $0, with: client) }
        .flatMapEachThrowing { updateTables(client: client, database: database, result: $0) }
        .flatMap { .andAllComplete($0, on: database.eventLoop) }
}


typealias PackageMetadata = (Package, Github.Metadata)


func fetchMetadata(for package: Package, with client: Client) -> EventLoopFuture<Result<PackageMetadata, Error>> {
    do {
        return try Current.fetchMetadata(client, package)
            .map { .success((package, $0)) }
            .flatMapErrorThrowing { .failure($0) }
    } catch {
        return client.eventLoop.makeSucceededFuture(.failure(error))
    }
}


func updateTables(client: Client, database: Database, result: Result<PackageMetadata, Error>) -> EventLoopFuture<Void> {
    do {
        let (pkg, md) = try result.get()
        return try insertOrUpdateRepository(on: database, for: pkg, metadata: md)
            .flatMap {
                pkg.status = .ok
                pkg.processingStage = .ingestion
                return pkg.save(on: database)
            }
    } catch {
        return recordError(client: client, database: database, error: error, stage: .ingestion)
    }
}


func insertOrUpdateRepository(on database: Database, for package: Package, metadata: Github.Metadata) throws -> EventLoopFuture<Void> {
    Repository.query(on: database)
        .filter(try \.$package.$id == package.requireID())
        .first()
        .flatMap { repo -> EventLoopFuture<Void> in
            if let repo = repo {
                repo.defaultBranch = metadata.defaultBranch
                repo.summary = metadata.description
                repo.forks = metadata.forksCount
                repo.license = .init(from: metadata.license)
                repo.stars = metadata.stargazersCount
                // TODO: find and assign parent repo
                return repo.save(on: database)
            } else {
                do {
                    return try Repository(package: package, metadata: metadata)
                        .save(on: database)
                } catch {
                    return database.eventLoop.makeFailedFuture(
                        AppError.genericError(package.id,
                                              "Failed to create Repository for \(package.url)")
                    )
                }
            }
        }
}


// TODO: sas: 2020-05-15: clean this up
func recordError(client: Client, database: Database, error: Error, stage: ProcessingStage) -> EventLoopFuture<Void> {
    let errorReport = Current.reportError(client, .error, error)

    func setStatus(id: Package.Id?, status: Status) -> EventLoopFuture<Void> {
        guard let id = id else { return database.eventLoop.future() }
        return Package.query(on: database)
            .filter(\.$id == id)
            .set(\.$processingStage, to: stage)
            .set(\.$status, to: status)
            .update()

    }

    database.logger.error("\(stage) error: \(error.localizedDescription)")

    guard let error = error as? AppError else { return errorReport }
    switch error {
        case .envVariableNotSet:
            break
        case let .genericError(id, _):
            return setStatus(id: id, status: .ingestionFailed)
        case let .invalidPackageCachePath(id, _):
            return setStatus(id: id, status: .analysisFailed)
        case let .invalidPackageUrl(id, _):
            return setStatus(id: id, status: .invalidUrl)
        case let .invalidRevision(id, _):
            return setStatus(id: id, status: .analysisFailed)
        case let .metadataRequestFailed(id, _, _):
            return setStatus(id: id, status: .metadataRequestFailed)
        case let .noValidVersions(id, _):
            return setStatus(id: id, status: .noValidVersions)
    }

    return errorReport
}
