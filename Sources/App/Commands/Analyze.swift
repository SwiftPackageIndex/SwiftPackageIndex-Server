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
import DependencyResolution
import Fluent
import SPIManifest
import ShellOut
import Vapor


enum Analyze {

    struct Command: AsyncCommand {
        typealias Signature = SPICommand.Signature

        var help: String { "Run package analysis (fetching git repository and inspecting content)" }

        func run(using context: CommandContext, signature: SPICommand.Signature) async throws {
            prepareDependencies {
                $0.logger = Logger(component: "analyze")
            }
            @Dependency(\.logger) var logger

            let client = context.application.client
            let db = context.application.db

            Analyze.resetMetrics()

            do {
                try await analyze(client: client,
                                  database: db,
                                  mode: .init(signature: signature))
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
        @Dependency(\.fileManager) var fileManager
        let checkoutDir = URL(
            fileURLWithPath: fileManager.checkoutsDirectory(),
            isDirectory: true
        )
        try fileManager.contentsOfDirectory(atPath: checkoutDir.path)
            .map { dir -> (String, Date)? in
                let url = checkoutDir.appendingPathComponent(dir)
                guard let mod = try fileManager
                    .attributesOfItem(atPath: url.path)[.modificationDate] as? Date
                else { return nil }
                return (url.path, mod)
            }
            .forEach { pair in
                guard let (path, mod) = pair else { return }
                @Dependency(\.date.now) var now
                @Dependency(\.fileManager) var fileManager
                let cutoff = now.addingTimeInterval(-Constants.gitCheckoutMaxAge)
                if mod < cutoff {
                    try fileManager.removeItem(atPath: path)
                    AppMetrics.analyzeTrimCheckoutsCount?.inc()
                }
            }
    }


    /// Analyze via a given mode: either one `Package` identified by its `Id` or a limited number of `Package`s.
    /// - Parameters:
    ///   - client: `Client` object
    ///   - database: `Database` object
    ///   - threadPool: `NIOThreadPool` (for running shell commands)
    ///   - mode: process a single `Package.Id` or a `limit` number of packages
    /// - Returns: future
    static func analyze(client: Client,
                        database: Database,
                        mode: SPICommand.Mode) async throws {
        let start = DispatchTime.now().uptimeNanoseconds
        defer { AppMetrics.analyzeDurationSeconds?.time(since: start) }

        @Dependency(\.logger) var logger

        switch mode {
            case .id(let id):
                logger.info("Analyzing (id: \(id)) ...")
                let pkg = try await Package.fetchCandidate(database, id: id)
                try await analyze(client: client, database: database, packages: [pkg])

            case .limit(let limit):
                logger.info("Analyzing (limit: \(limit)) ...")
                let packages = try await Package.fetchCandidates(database, for: .analysis, limit: limit)
                try await analyze(client: client, database: database, packages: packages)

            case .url(let url):
                logger.info("Analyzing (url: \(url)) ...")
                let pkg = try await Package.fetchCandidate(database, url: url)
                try await analyze(client: client, database: database, packages: [pkg])
        }
    }


    /// Main analysis function. Updates repostory checkouts, runs package dump, reconciles versions and updates packages.
    /// - Parameters:
    ///   - client: `Client` object
    ///   - database: `Database` object
    ///   - packages: packages to be analysed
    /// - Returns: future
    static func analyze(client: Client,
                        database: Database,
                        packages: [Joined<Package, Repository>]) async throws {
        AppMetrics.analyzeCandidatesCount?.set(packages.count)

        @Dependency(\.fileManager) var fileManager
        @Dependency(\.logger) var logger

        // get or create directory
        let checkoutDir = fileManager.checkoutsDirectory()
        logger.info("Checkout directory: \(checkoutDir)")
        if !fileManager.fileExists(atPath: checkoutDir) {
            try await createCheckoutsDirectory(client: client, path: checkoutDir)
        }

        let packageResults = await packages.mapAsync { pkg in
            await Result {
                try await analyze(client: client, database: database, package: pkg)
                return pkg
            }
        }

        try await updatePackages(client: client, database: database, results: packageResults)

        try await RecentPackage.refresh(on: database)
        try await RecentRelease.refresh(on: database)
        try await Search.refresh(on: database)
        try await Stats.refresh(on: database)
        try await WeightedKeyword.refresh(on: database)
    }


    static func analyze(client: Client,
                        database: Database,
                        package: Joined<Package, Repository>) async throws {
        try await refreshCheckout(package: package)

        @Dependency(\.logger) var logger

        // 2024-10-05 sas: We need to explicitly weave dependencies into the `transaction` closure, because escaping closures strip them.
        // https://github.com/pointfreeco/swift-dependencies/discussions/283#discussioncomment-10846172
        // This might not be needed in Vapor 5 / FluentKit 2
        // TODO: verify if this is still needed once we upgrade to Vapor 5 / FluentKit 2
        try await withEscapedDependencies { dependencies in
            try await database.transaction { tx in
                try await dependencies.yield {
                    try await updateRepository(on: tx, package: package)

                    let versionDelta = try await diffVersions(client: client, transaction: tx,
                                                              package: package)
                    let netDeleteCount = versionDelta.toDelete.count - versionDelta.toAdd.count
                    if netDeleteCount > 1 {
                        logger.warning("Suspicious loss of \(netDeleteCount) versions for package \(package.model.id)")
                    }

                    try await applyVersionDelta(on: tx, delta: versionDelta)

                    let newVersions = versionDelta.toAdd

                    mergeReleaseInfo(package: package, into: newVersions)

                    var versionsPkgInfo = [(Version, PackageInfo)]()
                    for version in newVersions {
                        if let pkgInfo = try? await getPackageInfo(package: package, version: version) {
                            versionsPkgInfo.append((version, pkgInfo))
                        }
                    }
                    if !newVersions.isEmpty && versionsPkgInfo.isEmpty {
                        throw AppError.noValidVersions(package.model.id, package.model.url)
                    }

                    for (version, pkgInfo) in versionsPkgInfo {
                        try await updateVersion(on: tx, version: version, packageInfo: pkgInfo)
                        try await recreateProducts(on: tx, version: version, manifest: pkgInfo.packageManifest)
                        try await recreateTargets(on: tx, version: version, manifest: pkgInfo.packageManifest)
                    }

                    let versions = try await updateLatestVersions(on: tx, package: package)

                    let targets = await fetchTargets(on: tx, package: package)

                    updateScore(package: package, versions: versions, targets: targets)

                    await onNewVersions(client: client, package: package, versions: newVersions)
                }
            }
        }
    }
    
    /// Fetch targets for a given `Package`
    /// - Parameters:
    ///   - database: `Database` object
    ///   - package: `Package` object
    /// - Returns: targets associated with package
    private static func fetchTargets(on database: Database, package: Joined<Package, Repository>) async -> [(String, TargetType)]? {
        guard let repo = package.repository, let owner = repo.owner, let repository = repo.name else {
            return nil
        }
        return try? await API.PackageController.Target.query(on: database, owner: owner, repository: repository)
    }


    static func createCheckoutsDirectory(client: Client,
                                         path: String) async throws {
        @Dependency(\.logger) var logger
        logger.info("Creating checkouts directory at path: \(path)")
        do {
            @Dependency(\.fileManager) var fileManager
            try fileManager.createDirectory(atPath: path,
                                            withIntermediateDirectories: false,
                                            attributes: nil)
        } catch {
            let error = AppError.genericError(nil, "Failed to create checkouts directory: \(error.localizedDescription)")
            logger.report(error: error)
        }
    }


    /// Run `git clone` for a given url in a given directory.
    /// - Parameters:
    ///   - cacheDir: checkout directory
    ///   - url: url to clone from
    /// - Throws: Shell errors
    static func clone(cacheDir: String, url: String) async throws {
        @Dependency(\.logger) var logger
        logger.info("cloning \(url) to \(cacheDir)")
        @Dependency(\.fileManager) var fileManager
        @Dependency(\.shell) var shell
        try await shell.run(command: .gitClone(url: URL(string: url)!, to: cacheDir),
                            at: fileManager.checkoutsDirectory())
    }


    /// Run `git fetch` and a set of supporting git commands (in order to allow the fetch to succeed more reliably).
    /// - Parameters:
    ///   - cacheDir: checkout directory
    ///   - branch: branch to check out
    ///   - url: url to fetch from
    /// - Throws: Shell errors
    static func fetch(cacheDir: String, branch: String, url: String) async throws {
        @Dependency(\.fileManager) var fileManager
        @Dependency(\.logger) var logger
        @Dependency(\.shell) var shell
        logger.info("pulling \(url) in \(cacheDir)")
        // clean up stray lock files that might have remained from aborted commands
        for fileName in ["HEAD.lock", "index.lock"] {
            let filePath = cacheDir + "/.git/\(fileName)"
            if fileManager.fileExists(atPath: filePath) {
                logger.info("Removing stale \(fileName) at path: \(filePath)")
                try await shell.run(command: .removeFile(from: filePath), at: .cwd)
            }
        }
        // git reset --hard to deal with stray .DS_Store files on macOS
        try await shell.run(command: .gitReset(hard: true), at: cacheDir)
        try await shell.run(command: .gitClean, at: cacheDir)
        try await shell.run(command: .gitFetchAndPruneTags, at: cacheDir)
        try await shell.run(command: .gitCheckout(branch: branch), at: cacheDir)
        try await shell.run(command: .gitReset(to: branch, hard: true), at: cacheDir)
    }


    /// Refresh git checkout (working copy) for a given package.
    /// - Parameters:
    ///   - package: `Package` to refresh
    static func refreshCheckout(package: Joined<Package, Repository>) async throws {
        @Dependency(\.fileManager) var fileManager
        @Dependency(\.logger) var logger
        @Dependency(\.shell) var shell

        guard let cacheDir = fileManager.cacheDirectoryPath(for: package.model) else {
            throw AppError.invalidPackageCachePath(package.model.id, package.model.url)
        }

        do {
            guard fileManager.fileExists(atPath: cacheDir) else {
                try await clone(cacheDir: cacheDir, url: package.model.url)
                return
            }

            // attempt to fetch - if anything goes wrong we delete the directory
            // and fall back to cloning
            do {
                try await fetch(cacheDir: cacheDir,
                                branch: package.repository?.defaultBranch ?? "master",
                                url: package.model.url)
            } catch {
                logger.info("fetch failed: \(error.localizedDescription)")
                try await shell.run(command: .removeFile(from: cacheDir, arguments: ["-r", "-f"]), at: .cwd)
                try await clone(cacheDir: cacheDir, url: package.model.url)
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
        @Dependency(\.fileManager) var fileManager
        @Dependency(\.git) var git

        guard let repo = package.repository else {
            throw AppError.genericError(package.model.id, "updateRepository: no repository")
        }
        guard let gitDirectory = fileManager.cacheDirectoryPath(for: package.model) else {
            throw AppError.invalidPackageCachePath(package.model.id, package.model.url)
        }

        repo.commitCount = (try? await git.commitCount(at: gitDirectory)) ?? 0
        repo.firstCommitDate = try? await git.firstCommitDate(at: gitDirectory)
        repo.lastCommitDate = try? await git.lastCommitDate(at: gitDirectory)
        repo.authors = try? await PackageContributors.extract(gitCacheDirectoryPath: gitDirectory, packageID: package.model.id)

        try await repo.update(on: database)
    }


    /// Find new, outdated, and unchanged versions for a given `Package`, based on a comparison of their immutable references - the pair (`Reference`, `CommitHash`) of each version.
    /// - Parameters:
    ///   - client: `Client` object (for Rollbar error reporting)
    ///   - transaction: database transaction
    ///   - package: `Package` to reconcile
    /// - Returns: future with array of pair of new, outdated, and unchanged `Version`s
    static func diffVersions(client: Client,
                             transaction: Database,
                             package: Joined<Package, Repository>) async throws -> VersionDelta {
        @Dependency(\.logger) var logger

        guard let pkgId = package.model.id else {
            throw AppError.genericError(nil, "PANIC: package id nil for package \(package.model.url)")
        }

        let existing = try await Version.query(on: transaction)
            .filter(\.$package.$id == pkgId)
            .all()
        let incoming = try await getIncomingVersions(client: client, package: package)

        let throttled = throttle(
            latestExistingVersion: existing.latestBranchVersion,
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
    ///   - package: `Package` to reconcile
    /// - Returns: future with incoming `Version`s
    static func getIncomingVersions(client: Client,
                                    package: Joined<Package, Repository>) async throws -> [Version] {
        @Dependency(\.fileManager) var fileManager
        @Dependency(\.git) var git
        
        guard let cacheDir = fileManager.cacheDirectoryPath(for: package.model) else {
            throw AppError.invalidPackageCachePath(package.model.id, package.model.url)
        }

        guard let defaultBranch = package.repository?.defaultBranch
            .map({ Reference.branch($0) })
        else {
            throw AppError.analysisError(package.model.id, "Package must have default branch")
        }

        guard try await git.hasBranch(defaultBranch, at: cacheDir) else {
            throw AppError.analysisError(package.model.id, "Default branch '\(defaultBranch)' does not exist in checkout")
        }

        let tags = try await git.getTags(at: cacheDir)

        let references = [defaultBranch] + tags
        return try await references
            .mapAsync { ref in
                let revInfo = try await git.revisionInfo(ref, at: cacheDir)
                let url = package.model.versionUrl(for: ref)
                return try Version(package: package.model,
                                   commit: revInfo.commit,
                                   commitDate: revInfo.date,
                                   reference: ref,
                                   url: url)
            }
    }


    static func throttle(latestExistingVersion: Version?, incoming: [Version]) -> [Version] {
        guard let existingVersion = latestExistingVersion else {
            // there's no existing branch version -> leave incoming alone (which will lead to addition)
            return incoming
        }

        guard let incomingVersion = incoming.latestBranchVersion else {
            // there's no incoming branch version -> leave incoming alone (which will lead to removal)
            return incoming
        }

        @Dependency(\.date.now) var now
        let ageOfExistingVersion = now.timeIntervalSinceReferenceDate - existingVersion.commitDate.timeIntervalSinceReferenceDate

        let resultingBranchVersion: Version
        if existingVersion.reference.branchName != incomingVersion.reference.branchName {
            // if branch names differ we've got a renamed default branch and want to make
            // sure it's updated as soon as possible -> no throttling
            resultingBranchVersion = incomingVersion
        } else {
            // if existing version isn't older than our "window", keep it - otherwise
            // use the latest incoming version
            if ageOfExistingVersion < Constants.branchVersionRefreshDelay {
                resultingBranchVersion = existingVersion
            } else {
                resultingBranchVersion = incomingVersion
            }
        }

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
        // Preserve certain existing default branch properties
        carryOverDefaultBranchData(versionDelta: delta)

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

    
    /// If `versionDelta` removes and adds a default branch version, copy certain properties
    /// over to the new version in order to avoid gaps in data display until downstream processes
    /// have processed the new version.
    /// - Parameter versionDelta: The version change
    static func carryOverDefaultBranchData(versionDelta: VersionDelta) {
        @Dependency(\.logger) var logger
        guard versionDelta.toDelete.filter(\.isBranch).count <= 1 else {
            logger.warning("versionDelta.toDelete has more than one branch version")
            return
        }
        guard versionDelta.toAdd.filter(\.isBranch).count <= 1 else {
            logger.warning("versionDelta.toAdd has more than one branch version")
            return
        }
        guard let oldDefaultBranch = versionDelta.toDelete.first(where: \.isBranch),
              let newDefaultBranch = versionDelta.toAdd.first(where: \.isBranch)
        else { return }
        // Preserve existing default branch doc archives to prevent a documentation gap
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2288
        if let existingDocArchives = oldDefaultBranch.docArchives {
            newDefaultBranch.docArchives = existingDocArchives
        }
        // Preserve dependency information
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2873
        if let existingResolvedDependencies = oldDefaultBranch.resolvedDependencies {
            newDefaultBranch.resolvedDependencies = existingResolvedDependencies
        }
        if let existingProductDependencies = oldDefaultBranch.productDependencies {
            newDefaultBranch.productDependencies = existingProductDependencies
        }
    }


    /// Run `swift package dump-package` for a package at the given path.
    /// - Parameters:
    ///   - path: path to the pacakge
    /// - Throws: Shell errors or AppError.invalidRevision if there is no Package.swift file
    /// - Returns: `Manifest` data
    static func dumpPackage(at path: String) async throws -> Manifest {
        @Dependency(\.fileManager) var fileManager
        @Dependency(\.shell) var shell
        guard fileManager.fileExists(atPath: path + "/Package.swift") else {
            // It's important to check for Package.swift - otherwise `dump-package` will go
            // up the tree through parent directories to find one
            throw AppError.invalidRevision(nil, "no Package.swift")
        }
        let json = try await shell.run(command: .swiftDumpPackage, at: path)
        return try JSONDecoder().decode(Manifest.self, from: Data(json.utf8))
    }


    struct PackageInfo: Equatable {
        var packageManifest: Manifest
        var spiManifest: SPIManifest.Manifest?
    }


    /// Get `Manifest` and `[ResolvedDepedency]` for a given `Package` at version `Version`.
    /// - Parameters:
    ///   - package: `Package` to analyse
    ///   - version: `Version` to check out
    /// - Returns: `Result` with `Manifest` data
    static func getPackageInfo(package: Joined<Package, Repository>, version: Version) async throws -> PackageInfo {
        // check out version in cache directory
        @Dependency(\.fileManager) var fileManager
        @Dependency(\.shell) var shell

        guard let cacheDir = fileManager.cacheDirectoryPath(for: package.model) else {
            throw AppError.invalidPackageCachePath(package.model.id,
                                                   package.model.url)
        }

        try await shell.run(command: .gitCheckout(branch: version.reference.description), at: cacheDir)

        do {
            let packageManifest = try await dumpPackage(at: cacheDir)
            @Dependency(\.environment) var environment
            let spiManifest = environment.loadSPIManifest(cacheDir)

            return PackageInfo(packageManifest: packageManifest,
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
                              packageInfo: PackageInfo) async throws {
        let manifest = packageInfo.packageManifest
        version.packageName = manifest.name
        version.swiftVersions = manifest.swiftLanguageVersions?.compactMap(SwiftVersion.init) ?? []
        version.supportedPlatforms = manifest.platforms?.compactMap(Platform.init(from:)) ?? []
        version.toolsVersion = manifest.toolsVersion?.version
        version.spiManifest = packageInfo.spiManifest
        version.hasBinaryTargets = packageInfo.packageManifest.targets.contains { $0.type == .binary }

        try await version.save(on: database)
    }


    static func recreateProducts(on database: Database, version: Version, manifest: Manifest) async throws {
        try await deleteProducts(on: database, version: version)
        try await createProducts(on: database, version: version, manifest: manifest)
    }


    /// Delete `Product`s for a given `versionId`.
    /// - Parameters:
    ///   - database: database connection
    ///   - version: parent model object
    /// - Returns: future
    static func deleteProducts(on database: Database, version: Version) async throws {
        guard let versionId = version.id else { return }
        try await Product.query(on: database)
            .filter(\.$version.$id == versionId)
            .delete()
    }


    /// Create and persist `Product`s for a given `Version` according to the given `Manifest`.
    /// - Parameters:
    ///   - database: `Database` object
    ///   - version: version to update
    ///   - manifest: `Manifest` data
    /// - Returns: future
    static func createProducts(on database: Database, version: Version, manifest: Manifest) async throws {
        try await manifest.products.compactMap { manifestProduct in
            try? Product(version: version,
                         type: .init(manifestProductType: manifestProduct.type),
                         name: manifestProduct.name,
                         targets: manifestProduct.targets)
        }
        .create(on: database)
    }


    static func recreateTargets(on database: Database, version: Version, manifest: Manifest) async throws {
        try await deleteTargets(on: database, version: version)
        try await createTargets(on: database, version: version, manifest: manifest)
    }


    /// Delete `Target`s for a given `versionId`.
    /// - Parameters:
    ///   - database: database connection
    ///   - version: parent model object
    /// - Returns: future
    static func deleteTargets(on database: Database, version: Version) async throws {
        guard let versionId = version.id else { return }
        try await Target.query(on: database)
            .filter(\.$version.$id == versionId)
            .delete()
    }


    /// Create and persist `Target`s for a given `Version` according to the given `Manifest`.
    /// - Parameters:
    ///   - database: `Database` object
    ///   - version: version to update
    ///   - manifest: `Manifest` data
    /// - Returns: future
    static func createTargets(on database: Database, version: Version, manifest: Manifest) async throws {
        try await manifest.targets.compactMap {
            try? Target(version: version, name: $0.name, type: .init(manifestTargetType: $0.type))
        }
        .create(on: database)
    }


    /// Update the significant versions (stable, beta, latest) for a given `Package`.
    /// - Parameters:
    ///   - database: `Database` object
    ///   - package: package to update
    /// - Returns: future
    @discardableResult
    static func updateLatestVersions(on database: Database, package: Joined<Package, Repository>) async throws -> [Version] {
        try await package.model.$versions.load(on: database)
        let versions = package.model.versions

        // find previous markers
        let previous = versions.filter { $0.latest != nil }

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
        for version in updates + resets {
            try await version.save(on: database)
        }

        return versions
    }


    /// Updates the score of the given `package` based on the given `package` itself and the given `Version`s. The `Version`s are passed in as a parameter to avoid re-fetching.
    /// - Parameters:
    ///   - package: `Package` input
    ///   - versions: `[Version]` input
    static func updateScore(package: Joined<Package, Repository>, versions: [Version], targets: [(String, TargetType)]? = nil) {
        if let details = Score.computeDetails(repo: package.repository, versions: versions, targets: targets) {
            package.model.score = details.score
            package.model.scoreDetails = details
        }
    }


    /// Event hook to run logic when new (tagged) versions have been discovered in an analysis pass. Note that the provided
    /// transaction could potentially be rolled back in case an error occurs before all versions are processed and saved.
    /// - Parameters:
    ///   - client: `Client` object for http requests
    ///   - transaction: `Database` object representing the current transaction
    ///   - package: package to update
    ///   - versions: array of new `Versions`s
    static func onNewVersions(client: Client,
                              package: Joined<Package, Repository>,
                              versions: [Version]) async {
        do {
            try await Social.postToFirehose(client: client,
                                            package: package,
                                            versions: versions)
        } catch {
            @Dependency(\.logger) var logger
            logger.warning("Social.postToFirehose failed: \(error.localizedDescription)")
        }
    }

}
