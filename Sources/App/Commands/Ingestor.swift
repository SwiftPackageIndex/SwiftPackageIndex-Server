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
        let request = ingest(application: context.application,
                             database: context.application.db,
                             limit: limit)
        context.console.info("Processing ...", newLine: true)
        try request.wait()
    }

}


func ingest(application: Application, database: Database, limit: Int) -> EventLoopFuture<Void> {
    let packages = Package.fetchCandidates(application.db, for: .ingestion, limit: limit)
    let metadata = packages.flatMap { fetchMetadata(client: application.client, packages: $0) }
    let updates = metadata.flatMap { updateRespositories(on: application.db, metadata: $0) }
    return updates.flatMap { updatePackage(application: application, results: $0, stage: .ingestion) }
}


typealias PackageMetadata = (Package, Github.Metadata)


func fetchMetadata(client: Client, packages: [Package]) -> EventLoopFuture<[Result<(Package, Github.Metadata), Error>]> {
    let ops = packages.map { pkg in Current.fetchMetadata(client, pkg).map { (pkg, $0) } }
    return EventLoopFuture.whenAllComplete(ops, on: client.eventLoop)
}


func updateRespositories(on database: Database, metadata: [Result<(Package, Github.Metadata), Error>]) -> EventLoopFuture<[Result<Package, Error>]> {
    let ops = metadata.map { result -> EventLoopFuture<Package> in
        switch result {
            case let .success((pkg, md)):
                return insertOrUpdateRepository(on: database, for: pkg, metadata: md)
                    .map { pkg }
            case let .failure(error):
                return database.eventLoop.future(error: error)
        }
    }
    return EventLoopFuture.whenAllComplete(ops, on: database.eventLoop)
}


func insertOrUpdateRepository(on database: Database, for package: Package, metadata: Github.Metadata) -> EventLoopFuture<Void> {
    guard let pkgId = try? package.requireID() else {
        return database.eventLoop.makeFailedFuture(AppError.genericError(nil, "package id not found"))
    }

    return Repository.query(on: database)
        .filter(\.$package.$id == pkgId)
        .first()
        .flatMap { repo -> EventLoopFuture<Void> in
            let repo = repo ?? Repository(packageId: pkgId)
            repo.defaultBranch = metadata.repo.defaultBranch
            repo.forks = metadata.repo.forksCount
            repo.lastIssueClosedAt = metadata.issues.first { $0.pullRequest == nil }?.closedAt
            repo.lastPullRequestClosedAt = metadata.issues.first { $0.pullRequest != nil }?.closedAt
            repo.license = .init(from: metadata.repo.license)
            repo.name = metadata.repo.name
            repo.openIssues = metadata.repo.openIssues
            repo.openPullRequests = metadata.openPullRequests.count
            repo.owner = metadata.repo.owner?.login
            repo.stars = metadata.repo.stargazersCount
            repo.summary = metadata.repo.description
            // TODO: find and assign parent repo
            return repo.save(on: database)
    }
}
