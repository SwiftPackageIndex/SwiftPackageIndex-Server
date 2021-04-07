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

        let client = context.application.client
        let db = context.application.db
        let logger = Logger(component: "ingest")

        if let id = signature.id {
            logger.info("Ingesting (id: \(id)) ...")
            try ingest(client: client, database: db, logger: logger, id: id)
                .wait()
        } else {
            logger.info("Ingesting (limit: \(limit)) ...")
            try ingest(client: client, database: db, logger: logger, limit: limit)
                .wait()
        }
        try AppMetrics.push(client: client,
                            logger: logger,
                            jobName: "ingest").wait()
    }
}


/// Ingest given `Package` identified by its `Id`.
/// - Parameters:
///   - client: `Client` object
///   - database: `Database` object
///   - logger: `Logger` object
///   - id: package id
/// - Returns: future
func ingest(client: Client,
            database: Database,
            logger: Logger,
            id: Package.Id) -> EventLoopFuture<Void> {
    Package.fetchCandidate(database, id: id)
        .map { [$0] }
        .flatMap { packages in
            ingest(client: client,
                   database: database,
                   logger: logger,
                   packages: packages)
        }
}


/// Ingest a number of `Package`s, selected from a candidate list with a given limit.
/// - Parameters:
///   - client: `Client` object
///   - database: `Database` object
///   - logger: `Logger` object
///   - limit: number of `Package`s to select from the candidate list
/// - Returns: future
func ingest(client: Client,
            database: Database,
            logger: Logger,
            limit: Int) -> EventLoopFuture<Void> {
    Package.fetchCandidates(database, for: .ingestion, limit: limit)
        .flatMap { ingest(client: client,
                          database: database,
                          logger: logger,
                          packages: $0) }
}


/// Main ingestion function. Fetched package metadata from hosting provider and updates `Repositoy` and `Package`s.
/// - Parameters:
///   - client: `Client` object
///   - database: `Database` object
///   - logger: `Logger` object
///   - packages: packages to be ingested
/// - Returns: future
func ingest(client: Client,
            database: Database,
            logger: Logger,
            packages: [Package]) -> EventLoopFuture<Void> {
    logger.info("Ingesting \(packages.compactMap {$0.id})")
    AppMetrics.ingestCandidatesCount?.set(packages.count)
    let metadata = fetchMetadata(client: client, packages: packages)
    let updates = metadata.flatMap { updateRepositories(on: database, metadata: $0) }
    return updates.flatMap { updatePackages(client: client,
                                            database: database,
                                            logger: logger,
                                            results: $0,
                                            stage: .ingestion) }
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
                AppMetrics.ingestMetadataSuccessTotal?.inc()
                return insertOrUpdateRepository(on: database,
                                                for: pkg,
                                                metadata: metadata,
                                                licenseInfo: licenseInfo,
                                                readmeInfo: readmeInfo)
                    .map { pkg }
            case let .failure(error):
                AppMetrics.ingestMetadataFailureTotal?.inc()
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
            guard let repository = metadata.repository else {
                return database.eventLoop.future(
                    error: AppError.genericError(pkgId, "repository is nil for package \(package.url)"))
            }
            let repo = repo ?? Repository(packageId: pkgId)
            repo.defaultBranch = repository.defaultBranch
            repo.forks = repository.forkCount
            repo.isArchived = repository.isArchived
            repo.lastIssueClosedAt = repository.lastIssueClosedAt
            repo.lastPullRequestClosedAt = repository.lastPullRequestClosedAt
            repo.license = .init(from: repository.licenseInfo)
            repo.licenseUrl = licenseInfo?.htmlUrl
            repo.name = repository.name
            repo.openIssues = repository.openIssues.totalCount
            repo.openPullRequests = repository.openPullRequests.totalCount
            repo.owner = repository.owner.login
            repo.readmeUrl = readmeInfo?.downloadUrl
            repo.readmeHtmlUrl = readmeInfo?.htmlUrl
            repo.releases = metadata.repository?.releases.nodes
                .map(Release.init(from:)) ?? []
            repo.stars = repository.stargazerCount
            repo.summary = repository.description
            // TODO: find and assign parent repo
            return repo.save(on: database)
        }
}
