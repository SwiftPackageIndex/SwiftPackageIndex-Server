// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
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


struct IngestCommand: AsyncCommand {
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

    func run(using context: CommandContext, signature: Signature) async throws {
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
            await ingest(client: client,
                         database: database,
                         logger: logger,
                         packages: [pkg])
        case .limit(let limit):
            logger.info("Ingesting (limit: \(limit)) ...")
            let packages = try await Package.fetchCandidates(database, for: .ingestion, limit: limit).get()
            await ingest(client: client,
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
            packages: [Joined<Package, Repository>]) async {
    logger.debug("Ingesting \(packages.compactMap {$0.model.id})")
    AppMetrics.ingestCandidatesCount?.set(packages.count)

    await withTaskGroup(of: Void.self) { group in
        for pkg in packages {
            group.addTask {
                let result = await Result {
                    let (metadata, license, readme) = try await fetchMetadata(client: client, package: pkg)
                    try await insertOrUpdateRepository(on: database, for: pkg, metadata: metadata, licenseInfo: license, readmeInfo: readme)
                    return pkg
                }

                switch result {
                    case .success:
                        AppMetrics.ingestMetadataSuccessCount?.inc()
                    case .failure:
                        AppMetrics.ingestMetadataFailureCount?.inc()
                }

                do {
                    try await updatePackage(client: client, database: database, logger: logger, result: result, stage: .ingestion)
                } catch {
                    logger.report(error: error)
                }
            }
        }
    }
}


func fetchMetadata(client: Client, package: Joined<Package, Repository>) async throws -> (Github.Metadata, Github.License?, Github.Readme?) {
    async let metadata = try await Current.fetchMetadata(client, package.model.url)
    async let license = await Current.fetchLicense(client, package.model.url)
    async let readme = await Current.fetchReadme(client, package.model.url)
    return try await (metadata, license, readme)
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

    let repositoryOwner = repository.owner.login
    let repositoryName = repository.name
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
    repo.name = repositoryName
    repo.openIssues = repository.openIssues.totalCount
    repo.openPullRequests = repository.openPullRequests.totalCount
    repo.owner = repositoryOwner
    repo.ownerName = repository.owner.name
    repo.ownerAvatarUrl = repository.owner.avatarUrl
    repo.releases = metadata.repository?.releases.nodes
        .map(Release.init(from:)) ?? []
    repo.stars = repository.stargazerCount
    repo.summary = repository.description

    try await repo.save(on: database)
}
