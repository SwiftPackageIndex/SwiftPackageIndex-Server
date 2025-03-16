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

import Dependencies
import Fluent
import PostgresKit
import Vapor


enum Ingestion {

    struct Error: ProcessingError {
        var packageId: Package.Id
        var underlyingError: UnderlyingError

        var description: String {
            "Ingestion.Error(\(packageId), \(underlyingError))"
        }

        enum UnderlyingError: Swift.Error, CustomStringConvertible {
            case fetchMetadataFailed(owner: String, name: String, details: String)
            case findOrCreateRepositoryFailed(url: String, details: Swift.Error)
            case invalidURL(String)
            case noRepositoryMetadata(owner: String?, name: String?)
            case repositorySaveFailed(owner: String?, name: String?, details: String)
            case repositorySaveUniqueViolation(owner: String?, name: String?, details: String)

            var description: String {
                switch self {
                    case let .fetchMetadataFailed(owner, name, details):
                        "fetchMetadataFailed(\(owner), \(name), \(details))"
                    case let .findOrCreateRepositoryFailed(url, details):
                        "findOrCreateRepositoryFailed(\(url), \(details))"
                    case let .invalidURL(url):
                        "invalidURL(\(url))"
                    case let .noRepositoryMetadata(owner, name):
                        "noRepositoryMetadata(\(owner), \(name))"
                    case let .repositorySaveFailed(owner, name, details):
                        "repositorySaveFailed(\(owner), \(name), \(details))"
                    case let .repositorySaveUniqueViolation(owner, name, details):
                        "repositorySaveUniqueViolation(\(owner), \(name), \(details))"
                }
            }
        }

        var level: Logger.Level {
            switch underlyingError {
                case .fetchMetadataFailed, .invalidURL, .noRepositoryMetadata:
                    return .warning
                case .findOrCreateRepositoryFailed, .repositorySaveFailed, .repositorySaveUniqueViolation:
                    return .critical
            }
        }

        var status: Package.Status {
            switch underlyingError {
                case .fetchMetadataFailed, .findOrCreateRepositoryFailed, .noRepositoryMetadata, .repositorySaveFailed:
                    return .ingestionFailed
                case .invalidURL:
                    return .invalidUrl
                case .repositorySaveUniqueViolation:
                    return .ingestionFailed
            }
        }
    }


    struct Command: AsyncCommand {
        typealias Signature = SPICommand.Signature

        var help: String { "Run package ingestion (fetching repository metadata)" }

        func run(using context: CommandContext, signature: SPICommand.Signature) async {
            prepareDependencies {
                $0.logger = Logger(component: "ingest")
            }
            @Dependency(\.logger) var logger

            let client = context.application.client
            let db = context.application.db

            Self.resetMetrics()

            do {
                try await ingest(client: client, database: db, mode: .init(signature: signature))
            } catch {
                logger.error("\(error.localizedDescription)")
            }

            do {
                try await AppMetrics.push(client: client,
                                          jobName: "ingest")
            } catch {
                logger.warning("\(error.localizedDescription)")
            }
        }

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
    static func ingest(client: Client,
                       database: Database,
                       mode: SPICommand.Mode) async throws {
        let start = DispatchTime.now().uptimeNanoseconds
        defer { AppMetrics.ingestDurationSeconds?.time(since: start) }

        @Dependency(\.logger) var logger

        switch mode {
            case .id(let id):
                logger.info("Ingesting (id: \(id)) ...")
                let pkg = try await Package.fetchCandidate(database, id: id)
                await ingest(client: client, database: database, packages: [pkg])

            case .limit(let limit):
                logger.info("Ingesting (limit: \(limit)) ...")
                let packages = try await Package.fetchCandidates(database, for: .ingestion, limit: limit)
                logger.info("Candidate count: \(packages.count)")
                await ingest(client: client, database: database, packages: packages)

            case .url(let url):
                logger.info("Ingesting (url: \(url)) ...")
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
    static func ingest(client: Client,
                       database: Database,
                       packages: [Joined<Package, Repository>]) async {
        @Dependency(\.logger) var logger
        logger.debug("Ingesting \(packages.compactMap {$0.model.id})")
        AppMetrics.ingestCandidatesCount?.set(packages.count)

        await withTaskGroup(of: Void.self) { group in
            for pkg in packages {
                group.addTask  {
                    await ingest(client: client, database: database, package: pkg)
                }
            }
        }
    }


    static func ingest(client: Client, database: Database, package: Joined<Package, Repository>) async {
        @Dependency(\.logger) var logger
        let result = await Result { () async throws(Ingestion.Error) -> Joined<Package, Repository> in
            @Dependency(\.environment) var environment
            logger.info("Ingesting \(package.package.url)")

            // Even though we have a `Joined<Package, Repository>` as a parameter, we must not rely
            // on `repository` for owner/name as it will be nil when a package is first ingested.
            // The only way to get `owner` and `repository` here is by parsing them from the URL.
            let (owner, repository) = try run {
                if environment.shouldFail(failureMode: .invalidURL) {
                    throw Github.Error.invalidURL(package.model.url)
                }
                return try Github.parseOwnerName(url: package.model.url)
            } rethrowing: { _ in
                Ingestion.Error.invalidURL(packageId: package.model.id!, url: package.model.url)
            }

            let (metadata, license, readme) = try await run {
                try await fetchMetadata(package: package.model, owner: owner, repository: repository)
            } rethrowing: {
                Ingestion.Error(packageId: package.model.id!,
                                underlyingError: .fetchMetadataFailed(owner: owner, name: repository, details: "\($0)"))
            }
            let repo = try await findOrCreateRepository(on: database, for: package)

            let s3Readme: S3Readme?
            do throws(S3Readme.Error) {
                s3Readme = try await storeS3Readme(repository: repo, metadata: metadata, readme: readme)
            } catch {
                // We don't want to fail ingestion in case storing the readme fails - warn and continue.
                logger.warning("storeS3Readme failed: \(error)")
                s3Readme = .error("\(error)")
            }

            let fork = await Ingestion.getFork(on: database, parent: metadata.repository?.parent)

            try await run { () async throws(Ingestion.Error.UnderlyingError) in
                try await Ingestion.updateRepository(on: database, for: repo, metadata: metadata, licenseInfo: license, readmeInfo: readme, s3Readme: s3Readme, fork: fork)
            } rethrowing: {
                Ingestion.Error(packageId: package.model.id!, underlyingError: $0)
            }
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
            logger.report(error: error)
        }
    }


    static func findOrCreateRepository(on database: Database, for package: Joined<Package, Repository>) async throws(Ingestion.Error) -> Repository {
        try await run {
            @Dependency(\.environment) var environment
            if environment.shouldFail(failureMode: .findOrCreateRepositoryFailed) {
                throw Abort(.internalServerError)
            }

            return try await Repository.findOrCreate(on: database, for: package.model)
        } rethrowing: {
            Ingestion.Error(
                packageId: package.model.id!,
                underlyingError: .findOrCreateRepositoryFailed(url: package.model.url, details: $0)
            )
        }
    }


    static func storeS3Readme(repository: Repository, metadata: Github.Metadata, readme: Github.Readme?) async throws(S3Readme.Error) -> S3Readme? {
        @Dependency(\.s3) var s3
        if let upstreamEtag = readme?.etag,
           repository.s3Readme?.needsUpdate(upstreamEtag: upstreamEtag) ?? true,
           let owner = metadata.repositoryOwner,
           let repository = metadata.repositoryName,
           let html = readme?.html {
            let objectUrl = try await s3.storeReadme(owner, repository, html)
            if let imagesToCache = readme?.imagesToCache, imagesToCache.isEmpty == false {
                try await s3.storeReadmeImages(imagesToCache)
            }
            return .cached(s3ObjectUrl: objectUrl, githubEtag: upstreamEtag)
        } else {
            return repository.s3Readme
        }
    }


    static func fetchMetadata(package: Package, owner: String, repository: String) async throws(Github.Error) -> (Github.Metadata, Github.License?, Github.Readme?) {
        @Dependency(\.environment) var environment
        if environment.shouldFail(failureMode: .fetchMetadataFailed) {
            throw Github.Error.requestFailed(.internalServerError)
        }

        // Need to pull in github functions individually, because otherwise the `async let` will trigger a
        // concurrency error if github gets used more than once:
        //   Sending 'github' into async let risks causing data races between async let uses and local uses
        @Dependency(\.github.fetchMetadata) var fetchMetadata
        @Dependency(\.github.fetchLicense) var fetchLicense
        @Dependency(\.github.fetchReadme) var fetchReadme

        async let metadata = try await fetchMetadata(owner, repository)
        async let license = await fetchLicense(owner, repository)
        async let readme = await fetchReadme(owner, repository)

        do {
            return try await (metadata, license, readme)
        } catch let error as Github.Error {
            throw error
        } catch {
            // This whole do { ... } catch { ... } should be unnecessary - it's a workaround for
            // https://github.com/swiftlang/swift/issues/76169
            assert(false, "Unexpected error type: \(type(of: error))")
            // We need to throw _something_ here (we should never hit this codepath though)
            throw Github.Error.requestFailed(.internalServerError)
            // We could theoretically avoid this whole second catch and just do
            //   error as! GithubError
            // but let's play it safe and not risk a server crash, unlikely as it may be.
        }
    }


    /// Insert or update `Repository` of given `Package` with given `Github.Metadata`.
    /// - Parameters:
    ///   - database: `Database` object
    ///   - package: package to update
    ///   - metadata: `Github.Metadata` with data for update
    /// - Returns: future
    static func updateRepository(on database: Database,
                                 for repository: Repository,
                                 metadata: Github.Metadata,
                                 licenseInfo: Github.License?,
                                 readmeInfo: Github.Readme?,
                                 s3Readme: S3Readme?,
                                 fork: Fork? = nil) async throws(Ingestion.Error.UnderlyingError) {
        @Dependency(\.environment) var environment
        if environment.shouldFail(failureMode: .noRepositoryMetadata) {
            throw .noRepositoryMetadata(owner: repository.owner, name: repository.name)
        }
        if environment.shouldFail(failureMode: .repositorySaveFailed) {
            throw .repositorySaveFailed(owner: repository.owner,
                                        name: repository.name,
                                        details: "TestError")
        }
        if environment.shouldFail(failureMode: .repositorySaveUniqueViolation) {
            throw .repositorySaveUniqueViolation(owner: repository.owner,
                                                 name: repository.name,
                                                 details: "TestError")
        }
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

        do {
            try await repository.save(on: database)
        } catch let error as PSQLError where error.isUniqueViolation {
            let details = error.serverInfo?[.message] ?? ""
            throw Ingestion.Error.UnderlyingError.repositorySaveUniqueViolation(owner: repository.owner,
                                                                                name: repository.name,
                                                                                details: details)
        } catch let error as PSQLError {
            let details = error.serverInfo?[.message] ?? ""
            throw Ingestion.Error.UnderlyingError.repositorySaveFailed(owner: repository.owner,
                                                                       name: repository.name,
                                                                       details: details)
        } catch {
            throw Ingestion.Error.UnderlyingError.repositorySaveFailed(owner: repository.owner,
                                                                       name: repository.name,
                                                                       details: "\(error)")
        }
    }

    static func getFork(on database: Database, parent: Github.Metadata.Parent?) async -> Fork? {
        guard let parentUrl = parent?.normalizedURL else { return nil }

        if let packageId = try? await Package.query(on: database)
            .filter(\.$url, .custom("ilike"), parentUrl)
            .first()?.id {
            return .parentId(id: packageId, fallbackURL: parentUrl)
        } else {
            return .parentURL(parentUrl)
        }
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


private extension Ingestion.Error {
    static func invalidURL(packageId: Package.Id, url: String) -> Self {
        Ingestion.Error(packageId: packageId, underlyingError: .invalidURL(url))
    }
}
