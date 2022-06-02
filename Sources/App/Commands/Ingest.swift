// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Vapor
import Fluent


struct IngestCommand: CommandAsync {
    let defaultLimit = 1
    
    struct Signature: CommandSignature {
        @Option(name: "limit", short: "l")
        var limit: Int?

        @Option(name: "id", help: "package id")
        var id: Package.Id?
    }
    
    var help: String { "Run package ingestion (fetching repository metadata)" }

    enum Mode {
        case id(Package.Id)
        case limit(Int)
    }

    func run(using context: CommandContext, signature: Signature) async {
        let limit = signature.limit ?? defaultLimit

        let client = context.application.client
        let db = context.application.db
        let logger = Logger(component: "ingest")

        Self.resetMetrics()

        let mode = signature.id.map(Mode.id) ?? .limit(limit)

        do {
            try await ingest(client: client, database: db, logger: logger, mode: mode)
        } catch {
            logger.error("\(error.localizedDescription)")
        }

        do {
            try await AppMetrics.push(client: client,
                                      logger: logger,
                                      jobName: "ingest")
        } catch {
            logger.warning("\(error.localizedDescription)")
        }
    }
}


extension IngestCommand {
    static func resetMetrics() {
        AppMetrics.ingestMetadataSuccessCount?.set(0)
        AppMetrics.ingestMetadataFailureCount?.set(0)
    }
}


/// Ingest via a given mode: either one `Package` identified by its `Id` or a limited number of `Package`s.
/// - Parameters:
///   - client: `Client` object
///   - database: `Database` object
///   - logger: `Logger` object
///   - mode: process a single `Package.Id` or a `limit` number of packages
/// - Returns: future
func ingest(client: Client,
            database: Database,
            logger: Logger,
            mode: IngestCommand.Mode) async throws {
    let start = DispatchTime.now().uptimeNanoseconds
    defer { AppMetrics.ingestDurationSeconds?.time(since: start) }

    switch mode {
        case .id(let id):
            logger.info("Ingesting (id: \(id)) ...")
            let pkg = try await Package.fetchCandidate(database, id: id).get()
            try await ingest(client: client,
                             database: database,
                             logger: logger,
                             packages: [pkg])
        case .limit(let limit):
            logger.info("Ingesting (limit: \(limit)) ...")
            let packages = try await Package.fetchCandidates(database, for: .ingestion, limit: limit).get()
            try await ingest(client: client,
                             database: database,
                             logger: logger,
                             packages: packages)
    }
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
            packages: [Joined<Package, Repository>]) async throws {
    logger.debug("Ingesting \(packages.compactMap {$0.model.id})")
    AppMetrics.ingestCandidatesCount?.set(packages.count)

    try await ingestFromGithub(client: client,
                               database: database,
                               logger: logger,
                               packages: packages)

    try await ingestFromS3(client: client,
                           database: database,
                           logger: logger,
                           packages: packages)
}


func ingestFromGithub(client: Client,
                      database: Database,
                      logger: Logger,
                      packages: [Joined<Package, Repository>]) async throws {
    // TODO: simplify the types in this chain by running the batches "vertically" instead of "horizontally"
    // i.e. instead of [package, data1, data2, ...] -> updatePackages(...)
    // run
    // let data1 = ...
    // let data2 = ...
    // updatePackage(...)
    // i.e. loop through each package end-to-end instead of building a wide tuple.
    // (I'm pretty sure none of the db queries are actually batch queries, so we wouldn't
    // introduce any extra latency. Should check if we could make them batch, though.)
    let metadata = await fetchMetadata(client: client, packages: packages)
    let updates = await updateRepositories(on: database, metadata: metadata)
    try await updatePackages(client: client,
                             database: database,
                             logger: logger,
                             results: updates,
                             stage: .ingestion).get()
}


func ingestFromS3(client: Client,
                  database: Database,
                  logger: Logger,
                  packages: [Joined<Package, Repository>]) async throws {
    // check for S3 bucket content
    // add new field to versions
    //   doc_archives text[]
    // for each package
    // - fetch versions where spi_manifest is not null and doc_archives is null (might need
    //   processing but has not been processed)
    // - if versions.documentation_targets is empty -> early out  *)
    // - fetch doc archives per version (logic in spi-s3-check)
    //       apple/swift-docc @ main - docc
    //       apple/swift-docc @ main - swiftdocc
    //       apple/swift-docc @ main - swiftdoccutilities
    // - merge each ref with versions.doc_archives
    // - cost saving:
    //   - set to [] for refs we don't have archives for
    //   - downside: if we generate those docs later we need to reset doc archives [] to NULL
    // - save update versions.docArchives
    //
    // *) allow for exceptions like apple/swift-docc and apple/swift-markdown which don't have
    //    spi manifest files
}

/// Fetch package metadata from hosting provider for a set of packages.
/// - Parameters:
///   - client: `Client` object to make HTTP requests.
///   - packages: packages to ingest
/// - Returns: results future
func fetchMetadata(
    client: Client, packages: [Joined<Package, Repository>]
) async -> [Result<(Joined<Package, Repository>, Github.Metadata, Github.License?, Github.Readme?), Error>] {
    await withThrowingTaskGroup(
        of: (Joined<Package, Repository>, Github.Metadata, Github.License?, Github.Readme?).self,
        returning: [Result<(Joined<Package, Repository>, Github.Metadata, Github.License?, Github.Readme?), Error>].self
    ) { group in
        for pkg in packages {
            group.addTask {
                async let metadata = try await Current.fetchMetadata(client, pkg.model.url)
                async let license = await Current.fetchLicense(client, pkg.model.url)
                async let readme = await Current.fetchReadme(client, pkg.model.url)
                return try await (pkg, metadata, license, readme)
            }
        }

        return await group.results()
    }
}


/// Update `Repository`s with metadata.
/// - Parameters:
///   - database: `Database` object
///   - metadata: result tuples of `(Package, Metadata)`
/// - Returns: results future
func updateRepositories(
    on database: Database,
    metadata: [Result<(Joined<Package, Repository>, Github.Metadata, Github.License?, Github.Readme?), Error>]
) async -> [Result<Joined<Package, Repository>, Error>] {
    await withThrowingTaskGroup(
        of: Joined<Package, Repository>.self,
        returning: [Result<Joined<Package, Repository>, Error>].self
    ) { group in
        for result in metadata {
            group.addTask {
                switch result {
                    case let .success((pkg, metadata, licenseInfo, readmeInfo)):
                        AppMetrics.ingestMetadataSuccessCount?.inc()
                        try await insertOrUpdateRepository(on: database,
                                                           for: pkg,
                                                           metadata: metadata,
                                                           licenseInfo: licenseInfo,
                                                           readmeInfo: readmeInfo)
                        return pkg
                    case let .failure(error):
                        AppMetrics.ingestMetadataFailureCount?.inc()
                        throw error
                }
            }
        }

        return await group.results()
    }
}


/// Insert or update `Repository` of given `Package` with given `Github.Metadata`.
/// - Parameters:
///   - database: `Database` object
///   - package: package to update
///   - metadata: `Github.Metadata` with data for update
/// - Returns: future
func insertOrUpdateRepository(on database: Database,
                              for package: Joined<Package, Repository>,
                              metadata: Github.Metadata,
                              licenseInfo: Github.License?,
                              readmeInfo: Github.Readme?) async throws {
    guard let pkgId = try? package.model.requireID() else {
        throw AppError.genericError(nil, "package id not found")
    }

    guard let repository = metadata.repository else {
        throw AppError.genericError(pkgId, "repository is nil for package \(package.model.url)")
    }

    let repo = try await Repository.query(on: database)
        .filter(\.$package.$id == pkgId)
        .first() ?? Repository(packageId: pkgId)
    repo.defaultBranch = repository.defaultBranch
    repo.forks = repository.forkCount
    repo.homepageUrl = repository.homepageUrl?.trimmed
    repo.isArchived = repository.isArchived
    repo.isInOrganization = repository.isInOrganization
    repo.keywords = Set(repository.topics.map { $0.lowercased() }).sorted()
    repo.lastIssueClosedAt = repository.lastIssueClosedAt
    repo.lastPullRequestClosedAt = repository.lastPullRequestClosedAt
    repo.license = .init(from: repository.licenseInfo)
    repo.licenseUrl = licenseInfo?.htmlUrl
    repo.name = repository.name
    repo.openIssues = repository.openIssues.totalCount
    repo.openPullRequests = repository.openPullRequests.totalCount
    repo.owner = repository.owner.login
    repo.ownerName = repository.owner.name
    repo.ownerAvatarUrl = repository.owner.avatarUrl
    repo.readmeUrl = readmeInfo?.downloadUrl
    repo.readmeHtmlUrl = readmeInfo?.htmlUrl
    repo.releases = metadata.repository?.releases.nodes
        .map(Release.init(from:)) ?? []
    repo.stars = repository.stargazerCount
    repo.summary = repository.description

    try await repo.save(on: database)
}
