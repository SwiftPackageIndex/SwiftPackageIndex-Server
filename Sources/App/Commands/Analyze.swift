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

import DependencyResolution
import Fluent
import SPIManifest
import ShellOut
import Vapor


enum Analyze {

    struct Command: CommandAsync {
        let defaultLimit = 1

        struct Signature: CommandSignature {
            @Option(name: "limit", short: "l")
            var limit: Int?
            @Option(name: "id")
            var id: UUID?
        }

        var help: String { "Run package analysis (fetching git repository and inspecting content)" }

        enum Mode {
            case id(Package.Id)
            case limit(Int)
        }

        func run(using context: CommandContext, signature: Signature) async {
            let limit = signature.limit ?? defaultLimit

            let client = context.application.client
            let db = context.application.db
            let logger = Logger(component: "analyze")

            Analyze.resetMetrics()

            let mode = signature.id.map(Mode.id) ?? .limit(limit)

            do {
                try await analyze(client: client,
                                  database: db,
                                  logger: logger,
                                  mode: mode)
            } catch {
                logger.error("\(error.localizedDescription)")
            }

            do {
                try Analyze.trimCheckouts()
            } catch {
                logger.error("\(error.localizedDescription)")
            }

            do {
                try await AppMetrics.push(client: client,
                                          logger: logger,
                                          jobName: "analyze")
            } catch {
                logger.warning("\(error.localizedDescription)")
            }
        }
    }

}


extension Analyze {

    static func resetMetrics() {
        AppMetrics.analyzeTrimCheckoutsCount?.set(0)
        AppMetrics.buildThrottleCount?.set(0)
        AppMetrics.analyzeVersionsAddedCount?.set(0)
        AppMetrics.analyzeVersionsDeletedCount?.set(0)
    }


    static func trimCheckouts() throws {
        let checkoutDir = URL(
            fileURLWithPath: Current.fileManager.checkoutsDirectory(),
            isDirectory: true
        )
        try Current.fileManager.contentsOfDirectory(atPath: checkoutDir.path)
            .map { dir -> (String, Date)? in
                let url = checkoutDir.appendingPathComponent(dir)
                guard let mod = try Current.fileManager
                    .attributesOfItem(atPath: url.path)[.modificationDate] as? Date
                else { return nil }
                return (url.path, mod)
            }
            .forEach { pair in
                guard let (path, mod) = pair else { return }
                let cutoff = Current.date()
                    .addingTimeInterval(-Constants.gitCheckoutMaxAge)
                if mod < cutoff {
                    try Current.fileManager.removeItem(atPath: path)
                    AppMetrics.analyzeTrimCheckoutsCount?.inc()
                }
            }
    }


    /// Analyze via a given mode: either one `Package` identified by its `Id` or a limited number of `Package`s.
    /// - Parameters:
    ///   - client: `Client` object
    ///   - database: `Database` object
    ///   - logger: `Logger` object
    ///   - threadPool: `NIOThreadPool` (for running shell commands)
    ///   - mode: process a single `Package.Id` or a `limit` number of packages
    /// - Returns: future
    static func analyze(client: Client,
                        database: Database,
                        logger: Logger,
                        mode: Analyze.Command.Mode) async throws {
        let start = DispatchTime.now().uptimeNanoseconds
        defer { AppMetrics.analyzeDurationSeconds?.time(since: start) }

        switch mode {
            case .id(let id):
                logger.info("Analyzing (id: \(id)) ...")
                let pkg = try await Package.fetchCandidate(database, id: id).get()
            
//                let url = pkg.model.url
//                let defaultBranch = pkg.repository?.defaultBranch ?? "master" 
//                print(defaultBranch)
//                logger.info("Analyzing (url: \(url)) ...")
//                let authors = pickAuthors(logger: logger, url: url, defaultBranch: defaultBranch)
//                logger.info("first author is \(authors.first?.identifier)")
            
            
                try await analyze(client: client,
                                  database: database,
                                  logger: logger,
                                  packages: [pkg])

            case .limit(let limit):
                logger.info("Analyzing (limit: \(limit)) ...")
                let packages = try await Package.fetchCandidates(database, for: .analysis, limit: limit).get()
                try await analyze(client: client,
                                  database: database,
                                  logger: logger,
                                  packages: packages)
        }
    }


    /// Main analysis function. Updates repostory checkouts, runs package dump, reconciles versions and updates packages.
    /// - Parameters:
    ///   - client: `Client` object
    ///   - database: `Database` object
    ///   - logger: `Logger` object
    ///   - packages: packages to be analysed
    /// - Returns: future
    static func analyze(client: Client,
                        database: Database,
                        logger: Logger,
                        packages: [Joined<Package, Repository>]) async throws {
        AppMetrics.analyzeCandidatesCount?.set(packages.count)

        // get or create directory
        let checkoutDir = Current.fileManager.checkoutsDirectory()
        logger.info("Checkout directory: \(checkoutDir)")
        if !Current.fileManager.fileExists(atPath: checkoutDir) {
            try await createCheckoutsDirectory(client: client, logger: logger, path: checkoutDir)
        }

        let packageResults = await withThrowingTaskGroup(
            of: Joined<Package, Repository>.self,
            returning: [Result<Joined<Package, Repository>, Error>].self
        ) { group in
            for pkg in packages {
                group.addTask {
                    let result = try await database.transaction { tx in
                        // Wrap in a Result to avoid throwing out of the transaction, causing a roll-back
                        await Result {
                            try await analyze(client: client,
                                              transaction: tx,
                                              logger: logger,
                                              package: pkg)
                        }
                    }
                    try result.get()

                    return pkg
                }
            }

            return await group.results()
        }

        try await updatePackages(client: client,
                                 database: database,
                                 logger: logger,
                                 results: packageResults,
                                 stage: .analysis).get()

        try await RecentPackage.refresh(on: database).get()
        try await RecentRelease.refresh(on: database).get()
        try await Search.refresh(on: database).get()
        try await Stats.refresh(on: database).get()
        try await WeightedKeyword.refresh(on: database).get()
    }


    static func analyze(client: Client,
                        transaction: Database,
                        logger: Logger,
                        package: Joined<Package, Repository>) async throws {
        try refreshCheckout(logger: logger, package: package)
        try await updateRepository(on: transaction, package: package)
        
        let authors = try pickAuthors(logger: logger, package: package)
        
        let contributors = try pickAcknowledgedContributors(logger: logger, package: package)


        let versionDelta = try await diffVersions(client: client,
                                                  logger: logger,
                                                  transaction: transaction,
                                                  package: package)

        try await applyVersionDelta(on: transaction, delta: versionDelta)

        let newVersions = versionDelta.toAdd

        mergeReleaseInfo(package: package, into: newVersions)

        let versionsPkgInfo = newVersions.compactMap { version -> (Version, PackageInfo)? in
            guard let pkgInfo = try? getPackageInfo(package: package, version: version) else { return nil }
            return (version, pkgInfo)
        }
        if !newVersions.isEmpty && versionsPkgInfo.isEmpty {
            throw AppError.noValidVersions(package.model.id, package.model.url)
        }

        for (version, pkgInfo) in versionsPkgInfo {
            try await updateVersion(on: transaction,
                                    version: version,
                                    packageInfo: pkgInfo).get()
            try await recreateProducts(on: transaction,
                                       version: version,
                                       manifest: pkgInfo.packageManifest)
            try await recreateTargets(on: transaction,
                                      version: version,
                                      manifest: pkgInfo.packageManifest)
        }

        try await updateLatestVersions(on: transaction, package: package).get()

        await onNewVersions(client: client,
                            logger: logger,
                            package: package,
                            versions: newVersions)
    }


    static func createCheckoutsDirectory(client: Client,
                                         logger: Logger,
                                         path: String) async throws {
        logger.info("Creating checkouts directory at path: \(path)")
        do {
            try Current.fileManager.createDirectory(atPath: path,
                                                    withIntermediateDirectories: false,
                                                    attributes: nil)
        } catch {
            let msg = "Failed to create checkouts directory: \(error.localizedDescription)"
            try await Current.reportError(client,
                                          .critical,
                                          AppError.genericError(nil, msg)).get()
            return
        }
    }


    /// Run `git clone` for a given url in a given directory.
    /// - Parameters:
    ///   - logger: `Logger` object
    ///   - cacheDir: checkout directory
    ///   - url: url to clone from
    /// - Throws: Shell errors
    static func clone(logger: Logger, cacheDir: String, url: String) throws {
        logger.info("cloning \(url) to \(cacheDir)")
        try Current.shell.run(command: .gitClone(url: URL(string: url)!, to: cacheDir),
                              at: Current.fileManager.checkoutsDirectory())
    }


    /// Run `git fetch` and a set of supporting git commands (in order to allow the fetch to succeed more reliably).
    /// - Parameters:
    ///   - logger: `Logger` object
    ///   - cacheDir: checkout directory
    ///   - branch: branch to check out
    ///   - url: url to fetch from
    /// - Throws: Shell errors
    static func fetch(logger: Logger, cacheDir: String, branch: String, url: String) throws {
        logger.info("pulling \(url) in \(cacheDir)")
        // clean up stray lock files that might have remained from aborted commands
        try ["HEAD.lock", "index.lock"].forEach { fileName in
            let filePath = cacheDir + "/.git/\(fileName)"
            if Current.fileManager.fileExists(atPath: filePath) {
                logger.info("Removing stale \(fileName) at path: \(filePath)")
                try Current.shell.run(command: .removeFile(from: filePath))
            }
        }
        // git reset --hard to deal with stray .DS_Store files on macOS
        try Current.shell.run(command: .gitReset(hard: true), at: cacheDir)
        try Current.shell.run(command: .gitClean, at: cacheDir)
        try Current.shell.run(command: .gitFetchAndPruneTags, at: cacheDir)
        try Current.shell.run(command: .gitCheckout(branch: branch), at: cacheDir)
        try Current.shell.run(command: .gitReset(to: branch, hard: true),
                              at: cacheDir)
    }


    /// Refresh git checkout (working copy) for a given package.
    /// - Parameters:
    ///   - logger: `Logger` object
    ///   - package: `Package` to refresh
    static func refreshCheckout(logger: Logger, package: Joined<Package, Repository>) throws {
        guard let cacheDir = Current.fileManager.cacheDirectoryPath(for: package.model) else {
            throw AppError.invalidPackageCachePath(package.model.id, package.model.url)
        }

        do {
            guard Current.fileManager.fileExists(atPath: cacheDir) else {
                try clone(logger: logger, cacheDir: cacheDir, url: package.model.url)
                return
            }

            // attempt to fetch - if anything goes wrong we delete the directory
            // and fall back to cloning
            do {
                try fetch(logger: logger,
                          cacheDir: cacheDir,
                          branch: package.repository?.defaultBranch ?? "master",
                          url: package.model.url)
            } catch {
                logger.info("fetch failed: \(error.localizedDescription)")
                logger.info("removing directory")
                try Current.shell.run(command: .removeFile(from: cacheDir, arguments: ["-r", "-f"]))
                try clone(logger: logger, cacheDir: cacheDir, url: package.model.url)
            }
        } catch {
            throw AppError.analysisError(package.model.id, "refreshCheckout failed: \(error.localizedDescription)")
        }
    }


    /// Update the `Repository` of a given `Package` with git repository data (commit count, first commit date, etc).
    /// - Parameters:
    ///   - database: `Database` object
    ///   - package: `Package` to update
    /// - Returns: result future
    static func updateRepository(on database: Database, package: Joined<Package, Repository>) async throws {
        guard let repo = package.repository else {
            throw AppError.genericError(package.model.id, "updateRepository: no repository")
        }
        guard let gitDirectory = Current.fileManager.cacheDirectoryPath(for: package.model) else {
            throw AppError.invalidPackageCachePath(package.model.id, package.model.url)
        }

        repo.commitCount = (try? Current.git.commitCount(gitDirectory)) ?? 0
        repo.firstCommitDate = try? Current.git.firstCommitDate(gitDirectory)
        repo.lastCommitDate = try? Current.git.lastCommitDate(gitDirectory)

        try await repo.update(on: database)
    }


    /// Find new, outdated, and unchanged versions for a given `Package`, based on a comparison of their immutable references - the pair (`Reference`, `CommitHash`) of each version.
    /// - Parameters:
    ///   - client: `Client` object (for Rollbar error reporting)
    ///   - logger: `Logger` object
    ///   - transaction: database transaction
    ///   - package: `Package` to reconcile
    /// - Returns: future with array of pair of new, outdated, and unchanged `Version`s
    static func diffVersions(client: Client,
                             logger: Logger,
                             transaction: Database,
                             package: Joined<Package, Repository>) async throws -> VersionDelta {
        guard let pkgId = package.model.id else {
            throw AppError.genericError(nil, "PANIC: package id nil for package \(package.model.url)")
        }

        let existing = try await Version.query(on: transaction)
            .filter(\.$package.$id == pkgId)
            .all()
        let incoming = try await getIncomingVersions(client: client, logger: logger, package: package)

        let throttled = throttle(
            lastestExistingVersion: existing.latestBranchVersion,
            incoming: incoming
        )
        let origDiff = Version.diff(local: existing, incoming: incoming)
        let newDiff = Version.diff(local: existing, incoming: throttled)
        let delta = origDiff.toAdd.count - newDiff.toAdd.count
        if delta > 0 {
            logger.info("throttled \(delta) incoming revisions")
            AppMetrics.buildThrottleCount?.inc(delta)
        }
        return newDiff
    }


    /// Get incoming versions (from git repository)
    /// - Parameters:
    ///   - client: `Client` object (for Rollbar error reporting)
    ///   - logger: `Logger` object
    ///   - package: `Package` to reconcile
    /// - Returns: future with incoming `Version`s
    static func getIncomingVersions(client: Client,
                                    logger: Logger,
                                    package: Joined<Package, Repository>) async throws -> [Version] {
        guard let cacheDir = Current.fileManager.cacheDirectoryPath(for: package.model) else {
            throw AppError.invalidPackageCachePath(package.model.id, package.model.url)
        }
        guard let pkgId = package.model.id else {
            throw AppError.genericError(nil, "PANIC: package id nil for package \(package.model.url)")
        }

        let defaultBranch = package.repository?.defaultBranch
            .map { Reference.branch($0) }

        let tags: [Reference]
        do {
            tags = try Current.git.getTags(cacheDir)
        } catch {
            let appError = AppError.genericError(pkgId, "Git.tag failed: \(error.localizedDescription)")
            logger.report(error: appError)
            try? await Current.reportError(client, .error, appError).get()
            tags = []
        }

        let references = [defaultBranch].compactMap { $0 } + tags
        return try references
            .map { ref in
                let revInfo = try Current.git.revisionInfo(ref, cacheDir)
                let url = package.model.versionUrl(for: ref)
                    return try Version(package: package.model,
                                       commit: revInfo.commit,
                                       commitDate: revInfo.date,
                                       reference: ref,
                                       url: url)
            }
    }


    static func throttle(lastestExistingVersion: Version?, incoming: [Version]) -> [Version] {
        guard let existingVersion = lastestExistingVersion else {
            // there's no existing branch version -> leave incoming alone (which will lead to addition)
            return incoming
        }

        guard let incomingVersion = incoming.latestBranchVersion else {
            // there's no incoming branch version -> leave incoming alone (which will lead to removal)
            return incoming
        }

        let ageOfExistingVersion = Current.date().timeIntervalSinceReferenceDate - existingVersion.commitDate.timeIntervalSinceReferenceDate

        // if existing version isn't older than our "window", keep it - otherwise
        // use the latest incoming version
        let resultingBranchVersion = ageOfExistingVersion < Constants.branchVersionRefreshDelay
        ? existingVersion
        : incomingVersion

        return incoming
            .filter(!\.isBranch)        // remove all branch versions
        + [resultingBranchVersion]  // add resulting version
    }


    static func mergeReleaseInfo(package: Joined<Package, Repository>, into versions: [Version]) {
        guard let releases = package.repository?.releases else { return }
        let tagToRelease = Dictionary(
            releases
                .filter { !$0.isDraft }
                .map { ($0.tagName, $0) },
            uniquingKeysWith: { $1 }
        )
        versions.forEach { version in
            guard let tagName = version.reference.tagName,
                  let rel = tagToRelease[tagName] else {
                return
            }
            version.publishedAt = rel.publishedAt
            version.releaseNotes = rel.description
            version.releaseNotesHTML = rel.descriptionHTML
            version.url = rel.url
        }
    }


    /// Saves and deletes the versions specified in the version delta parameter.
    /// - Parameters:
    ///   - transaction: transaction to run the save and delete in
    ///   - delta: tuple containing the versions to add and remove
    /// - Returns: future
    static func applyVersionDelta(on transaction: Database,
                                  delta: VersionDelta) async throws {
        try await delta.toDelete.delete(on: transaction)
        delta.toDelete.forEach {
            AppMetrics.analyzeVersionsDeletedCount?
                .inc(1, .versionLabels(reference: $0.reference))
        }
        try await delta.toAdd.create(on: transaction)
        delta.toAdd.forEach {
            AppMetrics.analyzeVersionsAddedCount?
                .inc(1, .versionLabels(reference: $0.reference))
        }
    }


    /// Run `swift package dump-package` for a package at the given path.
    /// - Parameters:
    ///   - path: path to the pacakge
    /// - Throws: Shell errors or AppError.invalidRevision if there is no Package.swift file
    /// - Returns: `Manifest` data
    static func dumpPackage(at path: String) throws -> Manifest {
        guard Current.fileManager.fileExists(atPath: path + "/Package.swift") else {
            // It's important to check for Package.swift - otherwise `dump-package` will go
            // up the tree through parent directories to find one
            throw AppError.invalidRevision(nil, "no Package.swift")
        }
        let json = try Current.shell.run(command: .swiftDumpPackage, at: path)
        return try JSONDecoder().decode(Manifest.self, from: Data(json.utf8))
    }


    struct PackageInfo: Equatable {
        var packageManifest: Manifest
        var dependencies: [ResolvedDependency]?
        var spiManifest: SPIManifest.Manifest?
    }


    /// Get `Manifest` and `[ResolvedDepedency]` for a given `Package` at version `Version`.
    /// - Parameters:
    ///   - package: `Package` to analyse
    ///   - version: `Version` to check out
    /// - Returns: `Result` with `Manifest` data
    static func getPackageInfo(package: Joined<Package, Repository>, version: Version) throws -> PackageInfo {
        // check out version in cache directory
        guard let cacheDir = Current.fileManager.cacheDirectoryPath(for: package.model) else {
            throw AppError.invalidPackageCachePath(package.model.id,
                                                   package.model.url)
        }

        try Current.shell.run(command: .gitCheckout(branch: version.reference.description), at: cacheDir)

        do {
            let packageManifest = try dumpPackage(at: cacheDir)
            let resolvedDependencies = getResolvedDependencies(Current.fileManager,
                                                               at: cacheDir)
            let spiManifest = Current.loadSPIManifest(cacheDir)

            return PackageInfo(packageManifest: packageManifest,
                               dependencies: resolvedDependencies,
                               spiManifest: spiManifest)
        } catch let AppError.invalidRevision(_, msg) {
            // re-package error to attach version.id
            throw AppError.invalidRevision(version.id, msg)
        }
    }


    /// Persist version changes to the database.
    /// - Parameters:
    ///   - database: `Database` object
    ///   - version: version to update
    ///   - manifest: `Manifest` data
    /// - Returns: future
    static func updateVersion(on database: Database,
                              version: Version,
                              packageInfo: PackageInfo) -> EventLoopFuture<Void> {
        let manifest = packageInfo.packageManifest
        version.packageName = manifest.name
        if let resolvedDependencies = packageInfo.dependencies {
            // Don't overwrite information provided by the build system unless it's a non-nil (i.e. valid) value
            version.resolvedDependencies = resolvedDependencies
        }
        version.swiftVersions = manifest.swiftLanguageVersions?.compactMap(SwiftVersion.init) ?? []
        version.supportedPlatforms = manifest.platforms?.compactMap(Platform.init(from:)) ?? []
        version.toolsVersion = manifest.toolsVersion?.version
        version.spiManifest = packageInfo.spiManifest
        version.hasBinaryTargets = packageInfo.packageManifest.targets.contains { $0.type == .binary }

        return version.save(on: database)
    }


    static func recreateProducts(on database: Database, version: Version, manifest: Manifest) async throws {
        try await deleteProducts(on: database, version: version).get()
        try await createProducts(on: database, version: version, manifest: manifest).get()
    }


    /// Delete `Product`s for a given `versionId`.
    /// - Parameters:
    ///   - database: database connection
    ///   - version: parent model object
    /// - Returns: future
    static func deleteProducts(on database: Database, version: Version) -> EventLoopFuture<Void> {
        guard let versionId = version.id else {
            return database.eventLoop.future()
        }
        return Product.query(on: database)
            .filter(\.$version.$id == versionId)
            .delete()
    }


    /// Create and persist `Product`s for a given `Version` according to the given `Manifest`.
    /// - Parameters:
    ///   - database: `Database` object
    ///   - version: version to update
    ///   - manifest: `Manifest` data
    /// - Returns: future
    static func createProducts(on database: Database, version: Version, manifest: Manifest) -> EventLoopFuture<Void> {
        manifest.products.compactMap { manifestProduct in
            try? Product(version: version,
                         type: .init(manifestProductType: manifestProduct.type),
                         name: manifestProduct.name,
                         targets: manifestProduct.targets)
        }
        .create(on: database)
    }


    static func recreateTargets(on database: Database, version: Version, manifest: Manifest) async throws {
        try await deleteTargets(on: database, version: version).get()
        try await createTargets(on: database, version: version, manifest: manifest).get()
    }


    /// Delete `Target`s for a given `versionId`.
    /// - Parameters:
    ///   - database: database connection
    ///   - version: parent model object
    /// - Returns: future
    static func deleteTargets(on database: Database, version: Version) -> EventLoopFuture<Void> {
        guard let versionId = version.id else {
            return database.eventLoop.future()
        }
        return Target.query(on: database)
            .filter(\.$version.$id == versionId)
            .delete()
    }


    /// Create and persist `Target`s for a given `Version` according to the given `Manifest`.
    /// - Parameters:
    ///   - database: `Database` object
    ///   - version: version to update
    ///   - manifest: `Manifest` data
    /// - Returns: future
    static func createTargets(on database: Database, version: Version, manifest: Manifest) -> EventLoopFuture<Void> {
        manifest.targets.compactMap { manifestTarget in
            try? Target(version: version, name: manifestTarget.name)
        }
        .create(on: database)
    }


    /// Update the significant versions (stable, beta, latest) for a given `Package`.
    /// - Parameters:
    ///   - database: `Database` object
    ///   - package: package to update
    /// - Returns: future
    static func updateLatestVersions(on database: Database, package: Joined<Package, Repository>) -> EventLoopFuture<Void> {
        package.model
            .$versions.load(on: database)
            .flatMap {
                // find previous markers
                let previous = package.model.versions
                    .filter { $0.latest != nil }

                let versions = package.model.$versions.value ?? []

                // find new significant releases
                let (release, preRelease, defaultBranch) = Package.findSignificantReleases(
                    versions: versions,
                    branch: package.repository?.defaultBranch
                )
                release.map { $0.latest = .release }
                preRelease.map { $0.latest = .preRelease }
                defaultBranch.map { $0.latest = .defaultBranch }
                let updates = [release, preRelease, defaultBranch].compactMap { $0 }

                // reset versions that aren't being updated
                let resets = previous
                    .filter { !updates.map(\.id).contains($0.id) }
                    .map { version -> Version in
                        version.latest = nil
                        return version
                    }

                // save changes
                return (updates + resets)
                    .map { $0.save(on: database) }
                    .flatten(on: database.eventLoop)
            }
    }


    /// Event hook to run logic when new (tagged) versions have been discovered in an analysis pass. Note that the provided
    /// transaction could potentially be rolled back in case an error occurs before all versions are processed and saved.
    /// - Parameters:
    ///   - client: `Client` object for http requests
    ///   - logger: `Logger` object
    ///   - transaction: `Database` object representing the current transaction
    ///   - package: package to update
    ///   - versions: array of new `Versions`s
    static func onNewVersions(client: Client,
                              logger: Logger,
                              package: Joined<Package, Repository>,
                              versions: [Version]) async {
        do {
            try await Twitter.postToFirehose(client: client,
                                             package: package,
                                             versions: versions).get()
        } catch {
            logger.warning("Twitter.postToFirehose failed: \(error.localizedDescription)")
        }
    }
    
    
    /// Selects the possible authors of the package according to the number of commits.
    /// A contributor is considered an author when the number of commits is at least a 60 percent
    /// of the maximum commits done by a contributor. A contritutor is acknowledge if the number of
    /// commits is at leat 2 percent of the maximum of commits.
    /// - Parameters:
    ///   - logger: `Logger` object
    ///   - package: The package in which we select the authors
    /// - Returns: Array of Contributors which were selected as authors
    static func pickAuthors(logger: Logger, package: Joined<Package, Repository>) throws -> [Contributor] {
        logger.info("Picking authors for \(package.model.url)")

        let gitHistoryLoader = GitHistoryLoader()
        let strategy = CommitSelector()
        let selector = AuthorPickerService(historyLoader: gitHistoryLoader,
                                           authorSelector: strategy)
        
        return try selector.selectAuthors(package: package)
        
    }
    
    /// Selects the contributors for acknowledgement according to the number of commits.
    /// A contritutor is acknowledged if the number of
    /// commits is at leat 2 percent of the maximum of commits.
    /// - Parameters:
    ///   - logger: `Logger` object
    ///   - package: The package in which we select the authors
    /// - Returns: Array of Contributors which were acknowledged by the number of commits
    static func pickAcknowledgedContributors(logger: Logger, package: Joined<Package, Repository>) throws -> [Contributor] {
        logger.info("Picking acknowledged contributors for \(package.model.url)")

        let gitHistoryLoader = GitHistoryLoader()
        let strategy = CommitSelector()
        let selector = AuthorPickerService(historyLoader: gitHistoryLoader,
                                           authorSelector: strategy)
        
        return try selector.selectContributors(package: package)
        
    }

}


extension App.FileManager: DependencyResolution.FileManager { }
