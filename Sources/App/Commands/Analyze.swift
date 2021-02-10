import Fluent
import Vapor
import ShellOut


struct AnalyzeCommand: Command {
    let defaultLimit = 1
    
    struct Signature: CommandSignature {
        @Option(name: "limit", short: "l")
        var limit: Int?
        @Option(name: "id")
        var id: UUID?
    }
    
    var help: String { "Run package analysis (fetching git repository and inspecting content)" }
    
    func run(using context: CommandContext, signature: Signature) throws {
        let limit = signature.limit ?? defaultLimit

        let client = context.application.client
        let db = context.application.db
        let logger = Logger(component: "analyze")
        let threadPool = context.application.threadPool

        if let id = signature.id {
            logger.info("Analyzing (id: \(id)) ...")
            try analyze(client: client,
                        database: db,
                        logger: logger,
                        threadPool: threadPool,
                        id: id)
                .wait()
        } else {
            logger.info("Analyzing (limit: \(limit)) ...")
            try analyze(client: client,
                        database: db,
                        logger: logger,
                        threadPool: threadPool,
                        limit: limit)
                .wait()
        }
        try AppMetrics.push(client: client,
                            logger: logger,
                            jobName: "analyze")
            .wait()
    }
}


/// Analyse a given `Package`, identified by its `Id`.
/// - Parameters:
///   - client: `Client` object
///   - database: `Database` object
///   - logger: `Logger` object
///   - threadPool: `NIOThreadPool` (for running shell commands)
///   - id: package id
/// - Returns: future
func analyze(client: Client,
             database: Database,
             logger: Logger,
             threadPool: NIOThreadPool,
             id: Package.Id) -> EventLoopFuture<Void> {
    Package.fetchCandidate(database, id: id)
        .map { [$0] }
        .flatMap {
            analyze(client: client,
                    database: database,
                    logger: logger,
                    threadPool: threadPool,
                    packages: $0)
        }
}


/// Analyse a number of `Package`s, selected from a candidate list with a given limit.
/// - Parameters:
///   - client: `Client` object
///   - database: `Database` object
///   - logger: `Logger` object
///   - threadPool: `NIOThreadPool` (for running shell commands)
///   - limit: number of `Package`s to select from the candidate list
/// - Returns: future
func analyze(client: Client,
             database: Database,
             logger: Logger,
             threadPool: NIOThreadPool,
             limit: Int) -> EventLoopFuture<Void> {
    Package.fetchCandidates(database, for: .analysis, limit: limit)
        .flatMap { analyze(client: client,
                           database: database,
                           logger: logger,
                           threadPool: threadPool,
                           packages: $0) }
}


/// Main analysis function. Updates repostory checkouts, runs package dump, reconciles versions and updates packages.
/// - Parameters:
///   - client: `Client` object
///   - database: `Database` object
///   - logger: `Logger` object
///   - threadPool: `NIOThreadPool` (for running shell commands)
///   - packages: packages to be analysed
/// - Returns: future
func analyze(client: Client,
             database: Database,
             logger: Logger,
             threadPool: NIOThreadPool,
             packages: [Package]) -> EventLoopFuture<Void> {
    AppMetrics.analyzeCandidatesCount?.set(packages.count)
    // get or create directory
    let checkoutDir = Current.fileManager.checkoutsDirectory()
    logger.info("Checkout directory: \(checkoutDir)")
    if !Current.fileManager.fileExists(atPath: checkoutDir) {
        logger.info("Creating checkouts directory at path: \(checkoutDir)")
        do {
            try Current.fileManager.createDirectory(atPath: checkoutDir,
                                                    withIntermediateDirectories: false,
                                                    attributes: nil)
        } catch {
            let msg = "Failed to create checkouts directory: \(error.localizedDescription)"
            return Current.reportError(client,
                                       .critical,
                                       AppError.genericError(nil, msg))
        }
    }
    
    let packages = refreshCheckouts(eventLoop: database.eventLoop,
                                    logger: logger,
                                    threadPool: threadPool,
                                    packages: packages)
        .flatMap { updateRepositories(on: database, packages: $0) }
    
    let packageResults = packages.flatMap { packages in
        database.transaction { tx in
            diffVersions(client: client,
                         logger: logger,
                         threadPool: threadPool,
                         transaction: tx,
                         packages: packages)
                .flatMap { mergeReleaseInfo(on: tx, packageDeltas: $0) }
                .flatMap { applyVersionDelta(on: tx, packageDeltas: $0) }
                .map { getManifests(packageAndVersions: $0) }
                .flatMap { updateVersions(on: tx, packageResults: $0) }
                .flatMap { updateProducts(on: tx, packageResults: $0) }
                .flatMap { updateTargets(on: tx, packageResults: $0) }
                .flatMap { updateLatestVersions(on: tx, packageResults: $0) }
                .flatMap { onNewVersions(client: client,
                                         logger: logger,
                                         transaction: tx,
                                         packageResults: $0)}
        }
    }
    
    let statusOps = packageResults
        .map(\.packages)
        .flatMap { updatePackages(client: client,
                                  database: database,
                                  logger: logger,
                                  results: $0,
                                  stage: .analysis) }
    
    let materializedViewRefresh = statusOps
        .flatMap { RecentPackage.refresh(on: database) }
        .flatMap { RecentRelease.refresh(on: database) }
        .flatMap { Search.refresh(on: database) }
        .flatMap { Stats.refresh(on: database) }
    
    return materializedViewRefresh
}


/// Refresh git checkouts (working copies) for a list of packages.
/// - Parameters:
///   - eventLoop: `EventLoop` object
///   - logger: `Logger` object
///   - threadPool: `NIOThreadPool` (for running shell commands)
///   - packages: list of `Packages`
/// - Returns: future with `Result`s
func refreshCheckouts(eventLoop: EventLoop,
                      logger: Logger,
                      threadPool: NIOThreadPool,
                      packages: [Package]) -> EventLoopFuture<[Result<Package, Error>]> {
    let ops = packages.map { refreshCheckout(eventLoop: eventLoop,
                                             logger: logger,
                                             threadPool: threadPool,
                                             package: $0) }
    return EventLoopFuture.whenAllComplete(ops, on: eventLoop)
}


/// Run `git clone` for a given url in a given directory.
/// - Parameters:
///   - logger: `Logger` object
///   - cacheDir: checkout directory
///   - url: url to clone from
/// - Throws: Shell errors
func clone(logger: Logger, cacheDir: String, url: String) throws {
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
func fetch(logger: Logger, cacheDir: String, branch: String, url: String) throws {
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
    try Current.shell.run(command: .init(string: "git reset --hard"), at: cacheDir)
    try Current.shell.run(command: .init(string: "git clean -fdx"), at: cacheDir)
    try Current.shell.run(command: .init(string: "git fetch --tags"), at: cacheDir)
    try Current.shell.run(command: .gitCheckout(branch: branch), at: cacheDir)
    try Current.shell.run(command: .init(string: #"git reset "origin/\#(branch)" --hard"#),
                          at: cacheDir)
}


/// Refresh git checkout (working copy) for a given package.
/// - Parameters:
///   - eventLoop: `EventLoop` object
///   - logger: `Logger` object
///   - threadPool: `NIOThreadPool` (for running shell commands)
///   - package: `Package` to refresh
/// - Returns: future
func refreshCheckout(eventLoop: EventLoop,
                     logger: Logger,
                     threadPool: NIOThreadPool,
                     package: Package) -> EventLoopFuture<Package> {
    guard let cacheDir = Current.fileManager.cacheDirectoryPath(for: package) else {
        return eventLoop.future(error: AppError.invalidPackageCachePath(package.id, package.url))
    }
    return threadPool.runIfActive(eventLoop: eventLoop) {
        do {
            guard Current.fileManager.fileExists(atPath: cacheDir) else {
                try clone(logger: logger, cacheDir: cacheDir, url: package.url)
                return
            }

            // attempt to fetch - if anything goes wrong we delete the directory
            // and fall back to cloning
            do {
                try fetch(logger: logger,
                          cacheDir: cacheDir,
                          branch: package.repository?.defaultBranch ?? "master",
                          url: package.url)
            } catch {
                logger.info("fetch failed: \(error.localizedDescription)")
                logger.info("removing directory")
                try Current.shell.run(command: .removeFile(from: cacheDir, arguments: ["-r", "-f"]))
                try clone(logger: logger, cacheDir: cacheDir, url: package.url)
            }
        } catch {
            throw AppError.analysisError(package.id, "refreshCheckout failed: \(error.localizedDescription)")
        }
    }
    .map { package }
}


/// Update the `Repository`s of a given set of `Package`s with git repository data (commit count, first commit date, etc).
/// - Parameters:
///   - database: `Database` object
///   - packages: `Package`s to update
/// - Returns: results future
func updateRepositories(on database: Database,
                        packages: [Result<Package, Error>]) -> EventLoopFuture<[Result<Package, Error>]> {
    let ops = packages.map { result -> EventLoopFuture<Package> in
        let updatedPackage = result.flatMap(updateRepository(package:))
        switch updatedPackage {
            case .success(let pkg):
                AppMetrics.analyzeUpdateRepositorySuccessTotal?.inc()
                return pkg.repositories.update(on: database).transform(to: pkg)
            case .failure(let error):
                AppMetrics.analyzeUpdateRepositoryFailureTotal?.inc()
                return database.eventLoop.future(error: error)
        }
    }
    return EventLoopFuture.whenAllComplete(ops, on: database.eventLoop)
}


/// Update the `Repository` of a given `Package` with git repository data (commit count, first commit date, etc).
/// - Parameter package: `Package` to update
/// - Returns: result future
func updateRepository(package: Package) -> Result<Package, Error> {
    guard let repo = package.repository else {
        return .failure(AppError.genericError(package.id, "updateRepository: no repository"))
    }
    guard let gitDirectory = Current.fileManager.cacheDirectoryPath(for: package) else {
        return .failure(AppError.invalidPackageCachePath(package.id, package.url))
    }
    
    return Result {
        repo.commitCount = try Current.git.commitCount(gitDirectory)
        repo.firstCommitDate = try Current.git.firstCommitDate(gitDirectory)
        repo.lastCommitDate = try Current.git.lastCommitDate(gitDirectory)
        return package
    }
}


/// Find new and outdated versions for a set of `Package`s, based on a comparison of their immutable references - the pair (`Reference`, `CommitHash`) of each version.
/// - Parameters:
///   - client: `Client` object (for Rollbar error reporting)
///   - logger: `Logger` object
///   - threadPool: `NIOThreadPool` (for running `git tag` commands)
///   - transaction: database transaction
///   - packages: `Package`s to reconcile
/// - Returns: results future with each `Package` and its pair of new and outdated `Version`s
func diffVersions(client: Client,
                  logger: Logger,
                  threadPool: NIOThreadPool,
                  transaction: Database,
                  packages: [Result<Package, Error>]) -> EventLoopFuture<[Result<(Package, VersionDelta), Error>]> {
    packages.whenAllComplete(on: transaction.eventLoop) { pkg in
        diffVersions(client: client,
                     logger: logger,
                     threadPool: threadPool,
                     transaction: transaction,
                     package: pkg)
            .map { (pkg, $0) }
    }
}


/// Find new, outdated, and unchanged versions for a given `Package`, based on a comparison of their immutable references - the pair (`Reference`, `CommitHash`) of each version.
/// - Parameters:
///   - client: `Client` object (for Rollbar error reporting)
///   - logger: `Logger` object
///   - threadPool: `NIOThreadPool` (for running `git tag` commands)
///   - transaction: database transaction
///   - package: `Package` to reconcile
/// - Returns: future with array of pair of new, outdated, and unchanged `Version`s
func diffVersions(client: Client,
                  logger: Logger,
                  threadPool: NIOThreadPool,
                  transaction: Database,
                  package: Package) -> EventLoopFuture<VersionDelta> {
    guard let cacheDir = Current.fileManager.cacheDirectoryPath(for: package) else {
        return transaction.eventLoop.future(error: AppError.invalidPackageCachePath(package.id, package.url))
    }
    guard let pkgId = package.id else {
        return transaction.eventLoop.future(error: AppError.genericError(nil, "PANIC: package id nil for package \(package.url)"))
    }

    let defaultBranch = package.repository?.defaultBranch
        .map { Reference.branch($0) }

    let tags: EventLoopFuture<[Reference]> = threadPool.runIfActive(eventLoop: transaction.eventLoop) {
        logger.info("listing tags for package \(package.url)")
        return try Current.git.getTags(cacheDir)
    }
    .flatMapError {
        let appError = AppError.genericError(pkgId, "Git.tag failed: \($0.localizedDescription)")
        logger.report(error: appError)
        return Current.reportError(client, .error, appError)
            .transform(to: [])
    }
    
    let references = tags.map { tags in [defaultBranch].compactMap { $0 } + tags }
    let incoming: EventLoopFuture<[Version]> = references
        .flatMapEachThrowing { ref in
            let revInfo = try Current.git.revisionInfo(ref, cacheDir)
            let url = package.versionUrl(for: ref)
            return try Version(package: package,
                               commit: revInfo.commit,
                               commitDate: revInfo.date,
                               reference: ref,
                               url: url) }
    
    return Version.query(on: transaction)
        .filter(\.$package.$id == pkgId)
        .all()
        .and(incoming)
        .map(Version.diff)
}


/// Merge release details from `Repository.releases` into the list of added `Version`s in a package delta.
/// - Parameters:
///   - transaction: transaction to run the save and delete in
///   - packageDeltas: tuples containing the `Package` and its new and outdated `Version`s
/// - Returns: future with an array of each `Package` paired with its update package delta for further processing
func mergeReleaseInfo(on transaction: Database,
                      packageDeltas: [Result<(Package, VersionDelta), Error>]) -> EventLoopFuture<[Result<(Package, VersionDelta), Error>]> {
    packageDeltas.whenAllComplete(on: transaction.eventLoop) { pkg, delta in
        mergeReleaseInfo(on: transaction, package: pkg, versions: delta.toAdd)
            .map { (pkg, .init(toAdd: $0,
                               toDelete: delta.toDelete,
                               toKeep: delta.toKeep)) }
    }
}


/// Merge release details from `Repository.releases` into a given list of `Version`s.
/// - Parameters:
///   - transaction: transaction to run the save and delete in
///   - package: `Package` the `Version`s belong to
///   - versions: list of `Verion`s to update
/// - Returns: update `Version`s
func mergeReleaseInfo(on transaction: Database,
                      package: Package,
                      versions: [Version]) -> EventLoopFuture<[Version]> {
    guard let releases = package.repository?.releases else {
        return transaction.eventLoop.future(versions)
    }
    let tagToRelease = Dictionary(releases
                                    .filter { !$0.isDraft }
                                    .map { ($0.tagName, $0) },
                                  uniquingKeysWith: { $1 })
    versions.forEach { version in
        guard let tagName = version.reference?.tagName,
              let rel = tagToRelease[tagName] else {
            return
        }
        version.publishedAt = rel.publishedAt
        version.releaseNotes = rel.description
        version.url = rel.url
    }
    return transaction.eventLoop.future(versions)
}


/// Saves and deletes the versions specified in the version delta parameter.
/// - Parameters:
///   - transaction: transaction to run the save and delete in
///   - packageDeltas: tuples containing the `Package` and its new and outdated `Version`s
/// - Returns: future with an array of each `Package` paired with its new `Version`s
func applyVersionDelta(on transaction: Database,
                       packageDeltas: [Result<(Package, VersionDelta), Error>]) -> EventLoopFuture<[Result<(Package, [Version]), Error>]> {
    packageDeltas.whenAllComplete(on: transaction.eventLoop) { pkg, delta in
        applyVersionDelta(on: transaction, delta: delta)
            .transform(to: (pkg, delta.toAdd))
    }
}


/// Saves and deletes the versions specified in the version delta parameter.
/// - Parameters:
///   - transaction: transaction to run the save and delete in
///   - delta: tuple containing the versions to add and remove
/// - Returns: future
func applyVersionDelta(on transaction: Database,
                       delta: VersionDelta) -> EventLoopFuture<Void> {
    let delete = delta.toDelete.delete(on: transaction)
    let insert = delta.toAdd.create(on: transaction)
    delta.toAdd.forEach {
        AppMetrics.analyzeVersionsAddedCount?.inc(1, .init($0.reference))
    }
    delta.toDelete.forEach {
        AppMetrics.analyzeVersionsDeletedCount?.inc(1, .init($0.reference))
    }
    return delete.flatMap { insert }
}


/// Get the package manifests for an array of `Package`s.
/// - Parameters:
///   - logger: `Logger` object
///   - packageAndVersions: `Result` containing the `Package` and the array of `Version`s to analyse
/// - Returns: results future including the `Manifest`s
func getManifests(packageAndVersions: [Result<(Package, [Version]), Error>]) -> [Result<(Package, [(Version, Manifest)]), Error>] {
    packageAndVersions.map { result -> Result<(Package, [(Version, Manifest)]), Error> in
        result.flatMap { (pkg, versions) -> Result<(Package, [(Version, Manifest)]), Error> in
            let m = versions.map { getManifest(package: pkg, version: $0) }
            let successes = m.compactMap { try? $0.get() }
            if !versions.isEmpty && successes.isEmpty {
                return .failure(AppError.noValidVersions(pkg.id, pkg.url))
            }
            return .success((pkg, successes))
        }
    }
}


/// Run `swift package dump-package` for a package at the given path.
/// - Parameters:
///   - path: path to the pacakge
/// - Throws: Shell errors or AppError.invalidRevision if there is no Package.swift file
/// - Returns: `Manifest` data
func dumpPackage(at path: String) throws -> Manifest {
    guard Current.fileManager.fileExists(atPath: path + "/Package.swift") else {
        // It's important to check for Package.swift - otherwise `dump-package` will go
        // up the tree through parent directories to find one
        throw AppError.invalidRevision(nil, "no Package.swift")
    }
    let swiftCommand = Current.fileManager.fileExists("/swift-5.3/usr/bin/swift")
        ? "/swift-5.3/usr/bin/swift"
        : "swift"
    let json = try Current.shell.run(command: .init(string: "\(swiftCommand) package dump-package"),
                                     at: path)
    return try JSONDecoder().decode(Manifest.self, from: Data(json.utf8))
}


/// Get `Manifest` for a given `Package` at version `Version`.
/// - Parameters:
///   - package: `Package` to analyse
///   - version: `Version` to check out
/// - Returns: `Result` with `Manifest` data
func getManifest(package: Package, version: Version) -> Result<(Version, Manifest), Error> {
    Result {
        // check out version in cache directory
        guard let cacheDir = Current.fileManager.cacheDirectoryPath(for: package) else {
            throw AppError.invalidPackageCachePath(package.id, package.url)
        }
        guard let reference = version.reference else {
            throw AppError.invalidRevision(version.id, nil)
        }

        try Current.shell.run(command: .gitCheckout(branch: reference.description), at: cacheDir)

        do {
            let manifest = try dumpPackage(at: cacheDir)
            return (version, manifest)
        } catch let AppError.invalidRevision(_, msg) {
            // re-package error to attach version.id
            throw AppError.invalidRevision(version.id, msg)
        }
    }
}


/// Update and save a given array of `Version` (as contained in `packageResults`) with data from the associated `Manifest`.
/// - Parameters:
///   - database: database connection
///   - packageResults: results to process, containing the versions and their manifests
/// - Returns: the input data for further processing, wrapped in a future
func updateVersions(on database: Database,
                    packageResults: [Result<(Package, [(Version, Manifest)]), Error>]) -> EventLoopFuture<[Result<(Package, [(Version, Manifest)]), Error>]> {
    packageResults.whenAllComplete(on: database.eventLoop) { (pkg, versionsAndManifests) in
        EventLoopFuture.andAllComplete(
            versionsAndManifests.map { version, manifest in
                updateVersion(on: database, version: version, manifest: manifest)
            },
            on: database.eventLoop
        )
        .transform(to: (pkg, versionsAndManifests))
    }
}


/// Persist version changes to the database.
/// - Parameters:
///   - database: `Database` object
///   - version: version to update
///   - manifest: `Manifest` data
/// - Returns: future
func updateVersion(on database: Database, version: Version, manifest: Manifest) -> EventLoopFuture<Void> {
    version.packageName = manifest.name
    version.swiftVersions = manifest.swiftLanguageVersions?.compactMap(SwiftVersion.init) ?? []
    version.supportedPlatforms = manifest.platforms?.compactMap(Platform.init(from:)) ?? []
    version.toolsVersion = manifest.toolsVersion?.version
    return version.save(on: database)
}


/// Update (delete and re-create) `Product`s from the `Manifest` data provided in `packageResults`.
/// - Parameters:
///   - database: database connection
///   - packageResults: results to process
/// - Returns: the input data for further processing, wrapped in a future
func updateProducts(on database: Database,
                    packageResults: [Result<(Package, [(Version, Manifest)]), Error>]) -> EventLoopFuture<[Result<(Package, [(Version, Manifest)]), Error>]> {
    packageResults.whenAllComplete(on: database.eventLoop) { (pkg, versionsAndManifests) in
        EventLoopFuture.andAllComplete(
            versionsAndManifests.map { version, manifest in
                deleteProducts(on: database, version: version)
                    .flatMap {
                        createProducts(on: database, version: version, manifest: manifest)
                    }
            },
            on: database.eventLoop
        )
        .transform(to: (pkg, versionsAndManifests))
    }
}


/// Delete `Product`s for a given `versionId`.
/// - Parameters:
///   - database: database connection
///   - version: parent model object
/// - Returns: future
func deleteProducts(on database: Database, version: Version) -> EventLoopFuture<Void> {
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
func createProducts(on database: Database, version: Version, manifest: Manifest) -> EventLoopFuture<Void> {
    manifest.products.compactMap { manifestProduct in
        try? Product(version: version,
                     type: .init(manifestProductType: manifestProduct.type),
                     name: manifestProduct.name,
                     targets: manifestProduct.targets)
    }
    .create(on: database)
}


/// Update (delete and re-create) `Target`s from the `Manifest` data provided in `packageResults`.
/// - Parameters:
///   - database: database connection
///   - packageResults: results to process
/// - Returns: the input data for further processing, wrapped in a future
func updateTargets(on database: Database,
                   packageResults: [Result<(Package, [(Version, Manifest)]), Error>]) -> EventLoopFuture<[Result<(Package, [(Version, Manifest)]), Error>]> {
    packageResults.whenAllComplete(on: database.eventLoop) { (pkg, versionsAndManifests) in
        EventLoopFuture.andAllComplete(
            versionsAndManifests.map { version, manifest in
                deleteTargets(on: database, version: version)
                    .flatMap {
                        createTargets(on: database, version: version, manifest: manifest)
                    }
            },
            on: database.eventLoop
        )
        .transform(to: (pkg, versionsAndManifests))
    }
}


/// Delete `Target`s for a given `versionId`.
/// - Parameters:
///   - database: database connection
///   - version: parent model object
/// - Returns: future
func deleteTargets(on database: Database, version: Version) -> EventLoopFuture<Void> {
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
func createTargets(on database: Database, version: Version, manifest: Manifest) -> EventLoopFuture<Void> {
    manifest.targets.compactMap { manifestTarget in
        try? Target(version: version, name: manifestTarget.name)
    }
    .create(on: database)
}


/// Update the significant versions (stable, beta, latest) for an array of `Package`s (contained in `packageResults`).
/// - Parameters:
///   - database: `Database` object
///   - packageResults: packages to update
/// - Returns: the input data for further processing, wrapped in a future
func updateLatestVersions(on database: Database,
                          packageResults: [Result<(Package, [(Version, Manifest)]), Error>]) -> EventLoopFuture<[Result<(Package, [(Version, Manifest)]), Error>]> {
    packageResults.whenAllComplete(on: database.eventLoop) { pkg, versionsAndManifests in
        updateLatestVersions(on: database, package: pkg)
            .map { _ in (pkg, versionsAndManifests) }
    }
}


/// Update the significant versions (stable, beta, latest) for a given `Package`.
/// - Parameters:
///   - database: `Database` object
///   - package: package to update
/// - Returns: future
func updateLatestVersions(on database: Database, package: Package) -> EventLoopFuture<Void> {
    package
        .$versions.load(on: database)
        .flatMap {
            // find previous markers
            let previous = package.versions.filter { $0.latest != nil }

            // find new significant releases
            let (release, preRelease, defaultBranch) = package.findSignificantReleases()
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
///   - transaction: database transaction
///   - packageResults: array of `Package`s with their analysis results of `Version`s and `Manifest`s
/// - Returns: the packageResults that were passed in, for further processing
func onNewVersions(client: Client,
                   logger: Logger,
                   transaction: Database,
                   packageResults: [Result<(Package, [(Version, Manifest)]), Error>]) -> EventLoopFuture<[Result<(Package, [(Version, Manifest)]), Error>]> {
    packageResults.whenAllComplete(on: transaction.eventLoop) { pkg, versionsAndManifests in
        let versions = versionsAndManifests.map { $0.0 }
        return Twitter.postToFirehose(client: client,
                                      database: transaction,
                                      package: pkg,
                                      versions: versions)
            .flatMapError { error in
                logger.warning("Twitter.postToFirehose failed: \(error.localizedDescription)")
                return client.eventLoop.future()
            }
            .map { (pkg, versionsAndManifests) }
    }
}


private extension Array where Element == Result<(Package,[(Version, Manifest)]), Error> {
    /// Helper to extract the nested `Package` results from the result tuple.
    /// - Returns: unpacked array of `Result<Package, Error>`
    var packages: [Result<Package, Error>]  {
        map { result in
            result.map { pkg, _ in
                pkg
            }
        }
    }
}
