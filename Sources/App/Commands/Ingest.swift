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


enum Ingestion {
    struct Error: Swift.Error, CustomStringConvertible {
        var packageId: Package.Id
        var underlyingError: UnderlyingError

        var description: String {
            "Ingestion.Error(\(packageId), \(underlyingError)"
        }

        enum UnderlyingError: Swift.Error, CustomStringConvertible {
            case fetchMetadataFailed(owner: String, name: String, details: Swift.Error)
            case findOrCreateRepositoryFailed(url: String, details: Swift.Error)
            case invalidURL(String)
            case noRepositoryMetadata(owner: String?, name: String?)
            case repositorySaveFailed(owner: String?, name: String?, details: Swift.Error)

            var description: String {
                switch self {
                    case let .fetchMetadataFailed(_, _, details):
                        "fetchMetadataFailed(\(details))"
                    case .findOrCreateRepositoryFailed:
                        "findOrCreateRepositoryFailed"
                    case let .invalidURL(url):
                        "invalidURL(\(url))"
                    case .noRepositoryMetadata:
                        "noRepositoryMetadata"
                    case let .repositorySaveFailed(_, _, details):
                        "repositorySaveFailed(\(details)"
                }
            }
        }
    }
}


struct IngestCommand: AsyncCommand {
    typealias Signature = SPICommand.Signature

    var help: String { "Run package ingestion (fetching repository metadata)" }

    func run(using context: CommandContext, signature: SPICommand.Signature) async throws {
        let client = context.application.client
        let db = context.application.db
        Current.setLogger(Logger(component: "ingest"))

        Self.resetMetrics()

        do {
            try await ingest(client: client, database: db, mode: .init(signature: signature))
        } catch {
            Current.logger().error("\(error.localizedDescription)")
        }

        do {
            try await AppMetrics.push(client: client,
                                      jobName: "ingest")
        } catch {
            Current.logger().warning("\(error.localizedDescription)")
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
///   - mode: process a single `Package.Id` or a `limit` number of packages
/// - Returns: future
func ingest(client: Client,
            database: Database,
            mode: SPICommand.Mode) async throws {
    let start = DispatchTime.now().uptimeNanoseconds
    defer { AppMetrics.ingestDurationSeconds?.time(since: start) }

    switch mode {
        case .id(let id):
            Current.logger().info("Ingesting (id: \(id)) ...")
            let pkg = try await Package.fetchCandidate(database, id: id)
            await ingest(client: client, database: database, packages: [pkg])

        case .limit(let limit):
            Current.logger().info("Ingesting (limit: \(limit)) ...")
            let packages = try await Package.fetchCandidates(database, for: .ingestion, limit: limit)
            Current.logger().info("Candidate count: \(packages.count)")
            await ingest(client: client, database: database, packages: packages)

        case .url(let url):
            Current.logger().info("Ingesting (url: \(url)) ...")
            let pkg = try await Package.fetchCandidate(database, url: url)
            await ingest(client: client, database: database, packages: [pkg])
    }
}


/// Main ingestion function. Fetched package metadata from hosting provider and updates `Repositoy` and `Package`s.
/// - Parameters:
///   - client: `Client` object
///   - database: `Database` object
///   - packages: packages to be ingested
/// - Returns: future
func ingest(client: Client,
            database: Database,
            packages: [Joined<Package, Repository>]) async {
    Current.logger().debug("Ingesting \(packages.compactMap {$0.model.id})")
    AppMetrics.ingestCandidatesCount?.set(packages.count)

    await withTaskGroup(of: Void.self) { group in
        for pkg in packages {
            group.addTask  {
                await Ingestion.ingestNew(client: client, database: database, package: pkg)
            }
        }
    }
}

func ingestOriginal(client: Client, database: Database, package: Joined<Package, Repository>) async {
    let result = await Result {
        Current.logger().info("Ingesting \(package.package.url)")
        let (metadata, license, readme) = try await fetchMetadata(client: client, package: package)
        let repo = try await Repository.findOrCreate(on: database, for: package.model)

        let s3Readme: S3Readme?
        do {
            if let upstreamEtag = readme?.etag,
               repo.s3Readme?.needsUpdate(upstreamEtag: upstreamEtag) ?? true,
               let owner = metadata.repositoryOwner,
               let repository = metadata.repositoryName,
               let html = readme?.html {
                let objectUrl = try await Current.storeS3Readme(owner, repository, html)
                if let imagesToCache = readme?.imagesToCache, imagesToCache.isEmpty == false {
                    try await Current.storeS3ReadmeImages(client, imagesToCache)
                }
                s3Readme = .cached(s3ObjectUrl: objectUrl, githubEtag: upstreamEtag)
            } else {
                s3Readme = repo.s3Readme
            }
        } catch {
            // We don't want to fail ingestion in case storing the readme fails - warn and continue.
            Current.logger().warning("storeS3Readme failed")
            s3Readme = .error("\(error)")
        }

        let fork = await getFork(on: database, parent: metadata.repository?.parent)

        try await updateRepository(on: database,
                                   for: repo,
                                   metadata: metadata,
                                   licenseInfo: license,
                                   readmeInfo: readme,
                                   s3Readme: s3Readme,
                                   fork: fork)
        return package
    }

    switch result {
        case .success:
            AppMetrics.ingestMetadataSuccessCount?.inc()
        case .failure:
            AppMetrics.ingestMetadataFailureCount?.inc()
    }

    do {
        try await updatePackage(client: client, database: database, result: result, stage: .ingestion)
    } catch {
        Current.logger().report(error: error)
    }
}


extension Ingestion {
    static func ingestNew(client: Client, database: Database, package: Joined<Package, Repository>) async {
        let result = await Result { () async throws(Ingestion.Error) -> Joined<Package, Repository> in
            Current.logger().info("Ingesting \(package.package.url)")
            let (metadata, license, readme) = try await fetchMetadata(client: client, package: package)
            let repo = try await Result {
                try await Repository.findOrCreate(on: database, for: package.model)
            }.mapError {
                Ingestion.Error(
                    packageId: package.model.id!,
                    underlyingError: .findOrCreateRepositoryFailed(url: package.package.url, details: $0)
                )
            }.get()

            let s3Readme: S3Readme?
            do throws(S3ReadmeError) {
                s3Readme = try await storeS3Readme(client: client, repository: repo, metadata: metadata, readme: readme)
            } catch {
                // We don't want to fail ingestion in case storing the readme fails - warn and continue.
                Current.logger().warning("storeS3Readme failed: \(error)")
                s3Readme = .error("\(error)")
            }

            let fork = await getFork(on: database, parent: metadata.repository?.parent)

            try await Result { () async throws(Ingestion.Error.UnderlyingError) in
                try await updateRepository(on: database, for: repo, metadata: metadata, licenseInfo: license, readmeInfo: readme, s3Readme: s3Readme, fork: fork)
            }.mapError {
                Error.init(packageId: package.model.id!, underlyingError: $0)
            }.get()
            return package
        }

        switch result {
            case .success:
                AppMetrics.ingestMetadataSuccessCount?.inc()
            case .failure:
                AppMetrics.ingestMetadataFailureCount?.inc()
        }

        do {
            try await updatePackage(client: client, database: database, result: result, stage: .ingestion)
        } catch {
            Current.logger().report(error: error)
        }
    }


    static func storeS3Readme(client: Client, repository: Repository, metadata: Github.Metadata, readme: Github.Readme?) async throws(S3ReadmeError) -> S3Readme? {
        if let upstreamEtag = readme?.etag,
           repository.s3Readme?.needsUpdate(upstreamEtag: upstreamEtag) ?? true,
           let owner = metadata.repositoryOwner,
           let repository = metadata.repositoryName,
           let html = readme?.html {
            let objectUrl = try await Current.storeS3Readme(owner, repository, html)
            if let imagesToCache = readme?.imagesToCache, imagesToCache.isEmpty == false {
                try await Current.storeS3ReadmeImages(client, imagesToCache)
            }
            return .cached(s3ObjectUrl: objectUrl, githubEtag: upstreamEtag)
        } else {
            return repository.s3Readme
        }
    }
}

func fetchMetadata(client: Client, package: Joined<Package, Repository>) async throws(Ingestion.Error) -> (Github.Metadata, Github.License?, Github.Readme?) {
    // Even though we get through a `Joined<Package, Repository>` as a parameter, it's
    // we must not rely on `repository` as it will be nil when a package is first ingested.
    // The only way to get `owner` and `repository` here is by parsing them from the URL.
    let (owner, repository) = try Result {
        try Github.parseOwnerName(url: package.model.url)
    }.mapError { _ in
        Ingestion.Error(packageId: package.model.id!,
                        underlyingError: .invalidURL(package.model.url))
    }.get()

    async let license = await Current.fetchLicense(client, owner, repository)
    async let readme = await Current.fetchReadme(client, owner, repository)

    // First one should be an `async let` as well but it doesn't compile right now. Reported as
    // https://github.com/swiftlang/swift/issues/76169
    return (try await Result { try await Current.fetchMetadata(client, owner, repository) }
        .mapError {
            Ingestion.Error(packageId: package.model.id!,
                            underlyingError: .fetchMetadataFailed(owner: owner, name: repository, details: $0))
        }
        .get(),
            await license,
            await readme)
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
                      s3Readme: S3Readme?,
                      fork: Fork? = nil) async throws(Ingestion.Error.UnderlyingError) {
    guard let repoMetadata = metadata.repository else {
        throw .noRepositoryMetadata(owner: repository.owner, name: repository.name)
    }

    repository.defaultBranch = repoMetadata.defaultBranch
    repository.forks = repoMetadata.forkCount
    repository.fundingLinks = repoMetadata.fundingLinks?.compactMap(FundingLink.init(from:)) ?? []
    repository.hasSPIBadge = readmeInfo?.containsSPIBadge()
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
    repository.forkedFrom = fork

    try await Result {
        try await repository.save(on: database)
    }.mapError {
        Ingestion.Error.UnderlyingError.repositorySaveFailed(owner: repository.owner, name: repository.name, details: $0)
    }.get()
}

func getFork(on database: Database, parent: Github.Metadata.Parent?) async -> Fork? {
    guard let parentUrl = parent?.normalizedURL else { return nil }

    if let packageId = try? await Package.query(on: database)
        .filter(\.$url, .custom("ilike"), parentUrl)
        .first()?.id {
        return .parentId(id: packageId, fallbackURL: parentUrl)
    } else {
        return .parentURL(parentUrl)
    }
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

private extension Github.Metadata.Parent {
    // Returns a normalized version of the URL. Adding a `.git` if not present.
    var normalizedURL: String? {
        guard let url else { return nil }
        guard let normalizedURL = URL(string: url)?.normalized?.absoluteString else {
            return nil
        }
        return normalizedURL
    }
}
