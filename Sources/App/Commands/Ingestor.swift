import Vapor
import Fluent


struct IngestCommand: Command {
    let defaultLimit = 1
    
    struct Signature: CommandSignature {
        @Option(name: "limit", short: "l")
        var limit: Int?

        @Option(name: "id", help: "package id")
        var id: Package.Id?
    }
    
    var help: String { "Run package ingestion (fetching repository metadata)" }
    
    func run(using context: CommandContext, signature: Signature) throws {
        let limit = signature.limit ?? defaultLimit
        if let id = signature.id {
            context.console.info("Ingesting (id: \(id)) ...")
            try ingest(application: context.application, id: id)
                .wait()
        } else {
            context.console.info("Ingesting (limit: \(limit)) ...")
            try ingest(application: context.application, limit: limit)
                .wait()
        }
    }
    
}


/// Ingest given `Package` identified by its `Id`.
/// - Parameters:
///   - application: `Application` object for database, client, and logger access
///   - id: package id
/// - Returns: future
func ingest(application: Application, id: Package.Id) -> EventLoopFuture<Void> {
    Package.query(on: application.db)
        .with(\.$repositories)
        .filter(\.$id == id)
        .first()
        .unwrap(or: Abort(.notFound))
        .map { [$0] }
        .flatMap { packages in
            ingest(application: application, packages: packages)
        }
}


/// Ingest a number of `Package`s, selected from a candidate list with a given limit.
/// - Parameters:
///   - application: `Application` object for database, client, and logger access
///   - limit: number of `Package`s to select from the candidate list
/// - Returns: future
func ingest(application: Application, limit: Int) -> EventLoopFuture<Void> {
    Package.fetchCandidates(application.db, for: .ingestion, limit: limit)
        .flatMap { ingest(application: application, packages: $0) }
}


/// Main ingestion function. Fetched package metadata from hosting provider and updates `Repositoy` and `Package`s.
/// - Parameters:
///   - application: `Application` object for database, client, and logger access
///   - packages: packages to be ingested
/// - Returns: future
func ingest(application: Application, packages: [Package]) -> EventLoopFuture<Void> {
    let metadata = fetchMetadata(client: application.client, packages: packages)
    let updates = metadata.flatMap { updateRepositories(on: application.db, metadata: $0) }
    return updates.flatMap { updatePackage(application: application, results: $0, stage: .ingestion) }
}


/// Fetch package metadata from hosting provider for a set of packages.
/// - Parameters:
///   - client: `Client` object to make HTTP requests.
///   - packages: packages to ingest
/// - Returns: results future
func fetchMetadata(
    client: Client, packages: [Package]
) -> EventLoopFuture<[Result<(Package, Github.Metadata, Github.License?, Github.Readme?), Error>]> {
    let ops = packages.map { pkg in
        Current.fetchMetadata(client, pkg)
            .and(Current.fetchLicense(client, pkg))
            .and(Current.fetchReadme(client, pkg))
            .map { (pkg, $0.0, $0.1, $1) }
    }
    return EventLoopFuture.whenAllComplete(ops, on: client.eventLoop)
}


/// Update `Repository`s with metadata.
/// - Parameters:
///   - database: `Database` object
///   - metadata: result tuples of `(Package, Metadata)`
/// - Returns: results future
func updateRepositories(
    on database: Database,
    metadata: [Result<(Package, Github.Metadata, Github.License?, Github.Readme?), Error>]
) -> EventLoopFuture<[Result<Package, Error>]> {
    let ops = metadata.map { result -> EventLoopFuture<Package> in
        switch result {
            case let .success((pkg, metadata, licenseInfo, readmeInfo)):
                return insertOrUpdateRepository(on: database,
                                                for: pkg,
                                                metadata: metadata,
                                                licenseInfo: licenseInfo,
                                                readmeInfo: readmeInfo)
                    .map { pkg }
            case let .failure(error):
                return database.eventLoop.future(error: error)
        }
    }
    return EventLoopFuture.whenAllComplete(ops, on: database.eventLoop)
}


/// Insert of update `Repository` of given `Package` with given `Github.Metadata`.
/// - Parameters:
///   - database: `Database` object
///   - package: package to update
///   - metadata: `Github.Metadata` with data for update
/// - Returns: future
func insertOrUpdateRepository(on database: Database,
                              for package: Package,
                              metadata: Github.Metadata,
                              licenseInfo: Github.License?,
                              readmeInfo: Github.Readme?) -> EventLoopFuture<Void> {
    guard let pkgId = try? package.requireID() else {
        return database.eventLoop.future(error: AppError.genericError(nil, "package id not found"))
    }

    return Repository.query(on: database)
        .filter(\.$package.$id == pkgId)
        .first()
        .flatMap { repo -> EventLoopFuture<Void> in
            let repo = repo ?? Repository(packageId: pkgId)
            guard let repository = metadata.repository else {
                return database.eventLoop.future(
                    error: AppError.genericError(pkgId, "repository is nil for package \(package.url)"))
            }
            repo.defaultBranch = repository.defaultBranch
            repo.forks = repository.forkCount
            repo.lastIssueClosedAt = repository.lastIssueClosedAt
            repo.lastPullRequestClosedAt = repository.lastPullRequestClosedAt
            repo.license = .init(from: repository.licenseInfo)
            repo.licenseUrl = licenseInfo?.htmlUrl
            repo.name = repository.name
            repo.openIssues = repository.openIssues.totalCount
            repo.openPullRequests = repository.openPullRequests.totalCount
            repo.owner = repository.owner.login
            repo.readmeUrl = readmeInfo?.htmlUrl
            repo.stars = repository.stargazerCount
            repo.summary = repository.description
            // TODO: find and assign parent repo
            return repo.save(on: database)
        }
}
