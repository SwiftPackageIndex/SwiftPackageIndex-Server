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
    typealias Signature = SPICommand.Signature

    var help: String { "Run package ingestion (fetching repository metadata)" }

    func run(using context: CommandContext, signature: SPICommand.Signature) async throws {
        let client = context.application.client
        let db = context.application.db
        let logger = Logger(component: "ingest")

        Self.resetMetrics()

        do {
            try await ingest(client: client, database: db, logger: logger, mode: .init(signature: signature))
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
            mode: SPICommand.Mode) async throws {
    let start = DispatchTime.now().uptimeNanoseconds
    defer { AppMetrics.ingestDurationSeconds?.time(since: start) }

    switch mode {
        case .id(let id):
            logger.info("Ingesting (id: \(id)) ...")
            let pkg = try await Package.fetchCandidate(database, id: id)
            await ingest(client: client, database: database, logger: logger, packages: [pkg])

        case .limit(let limit):
            logger.info("Ingesting (limit: \(limit)) ...")
            let packages = try await Package.fetchCandidates(database, for: .ingestion, limit: limit)
            logger.info("Candidate count: \(packages.count)")
            await ingest(client: client, database: database, logger: logger, packages: packages)

        case .url(let url):
            logger.info("Ingesting (url: \(url)) ...")
            let pkg = try await Package.fetchCandidate(database, url: url)
            await ingest(client: client, database: database, logger: logger, packages: [pkg])
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
                    let repo = try await Repository.findOrCreate(on: database, for: pkg.model)

                    let s3Readme: S3Readme?
                    do {
                        if let upstreamEtag = readme?.etag,
                           repo.s3Readme?.needsUpdate(upstreamEtag: upstreamEtag) ?? true,
                           let owner = metadata.repositoryOwner,
                           let repository = metadata.repositoryName,
                           let html = readme?.html {
                            let objectUrl = try await Current.storeS3Readme(client, owner, repository, html)
#warning("Move back to storeReadmeImage")
                            s3Readme = .cached(s3ObjectUrl: objectUrl, githubEtag: upstreamEtag)
                        } else {
                            s3Readme = repo.s3Readme
                        }
                    } catch {
                        // We don't want to fail ingestion in case storing the readme fails - warn and continue.
                        logger.warning("storeS3Readme failed")
                        s3Readme = .error("\(error)")
                    }

                    try await updateRepository(on: database,
                                               for: repo,
                                               metadata: metadata,
                                               licenseInfo: license,
                                               readmeInfo: readme,
                                               s3Readme: s3Readme)
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
    // TODO: Pass through `owner` and `repository` to all these calls so that they can use `apiUri(owner:repository:resource:query:)`
    async let metadata = try await Current.fetchMetadata(client, package.model.url)
    async let license = await Current.fetchLicense(client, package.model.url)

    guard let owner = package.repository?.owner, let repository = package.repository?.name
    else { return try await (metadata, license, nil) }

    async let readme = await Current.fetchReadme(client, owner, repository)
    return try await (metadata, license, readme)
}


/// Insert or update `Repository` of given `Package` with given `Github.Metadata`.
/// - Parameters:
///   - database: `Database` object
///   - package: package to update
///   - metadata: `Github.Metadata` with data for update
/// - Returns: future
func updateRepository(on database: Database,
                      for repository: Repository,
                      metadata: Github.Metadata,
                      licenseInfo: Github.License?,
                      readmeInfo: Github.Readme?,
                      s3Readme: S3Readme?) async throws {
    guard let repoMetadata = metadata.repository else {
        if repository.$package.value == nil {
            try await repository.$package.load(on: database)
        }
        throw AppError.genericError(repository.package.id,
                                    "repository metadata is nil for package \(repository.name ?? "unknown")")
    }

    repository.defaultBranch = repoMetadata.defaultBranch
    repository.forks = repoMetadata.forkCount
    repository.fundingLinks = repoMetadata.fundingLinks?.compactMap(FundingLink.init(from:)) ?? []
    repository.homepageUrl = repoMetadata.homepageUrl?.trimmed
    repository.isArchived = repoMetadata.isArchived
    repository.isInOrganization = repoMetadata.isInOrganization
    repository.keywords = Set(repoMetadata.topics.map { $0.lowercased() }).sorted()
    repository.lastIssueClosedAt = repoMetadata.lastIssueClosedAt
    repository.lastPullRequestClosedAt = repoMetadata.lastPullRequestClosedAt
    repository.license = .init(from: repoMetadata.licenseInfo)
    repository.licenseUrl = licenseInfo?.htmlUrl
    repository.name = repoMetadata.repositoryName
    repository.openIssues = repoMetadata.openIssues.totalCount
    repository.openPullRequests = repoMetadata.openPullRequests.totalCount
    repository.owner = repoMetadata.repositoryOwner
    repository.ownerName = repoMetadata.owner.name
    repository.ownerAvatarUrl = repoMetadata.owner.avatarUrl
    repository.s3Readme = s3Readme
    repository.readmeHtmlUrl = readmeInfo?.htmlUrl
    repository.releases = repoMetadata.releases.nodes.map(Release.init(from:))
    repository.stars = repoMetadata.stargazerCount
    repository.summary = repoMetadata.description

    try await repository.save(on: database)
}


// Helper to ensure the canonical source for these critical fields is the same in all the places where we need them
private extension Github.Metadata {
    var repositoryOwner: String? { repository?.repositoryOwner }
    var repositoryName: String? { repository?.repositoryName }
}

// Helper to ensure the canonical source for these critical fields is the same in all the places where we need them
private extension Github.Metadata.Repository {
    var repositoryOwner: String? { owner.login }
    var repositoryName: String? { name }
}
