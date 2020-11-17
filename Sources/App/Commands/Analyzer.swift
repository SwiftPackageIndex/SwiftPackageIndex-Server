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
        if let id = signature.id {
            context.console.info("Analyzing (id: \(id)) ...")
            try analyze(application: context.application, id: id).wait()
        } else {
            context.console.info("Analyzing (limit: \(limit)) ...")
            try analyze(application: context.application, limit: limit).wait()
        }
        try AppMetrics.push(client: context.application.client,
                            jobName: "analyze").wait()
    }
}


/// Analyse a given `Package`, identified by its `Id`.
/// - Parameters:
///   - application: `Application` object for database, client, and logger access
///   - id: package id
/// - Returns: future
func analyze(application: Application, id: Package.Id) -> EventLoopFuture<Void> {
    Package.query(on: application.db)
        .with(\.$repositories)
        .filter(\.$id == id)
        .first()
        .unwrap(or: Abort(.notFound))
        .map { [$0] }
        .flatMap {
            analyze(application: application, packages: $0)
        }
}


/// Analyse a number of `Package`s, selected from a candidate list with a given limit.
/// - Parameters:
///   - application: `Application` object for database, client, and logger access
///   - limit: number of `Package`s to select from the candidate list
/// - Returns: future
func analyze(application: Application, limit: Int) -> EventLoopFuture<Void> {
    Package.fetchCandidates(application.db, for: .analysis, limit: limit)
        .flatMap { analyze(application: application, packages: $0) }
}


/// Main analysis function. Updates repostory checkouts, runs package dump, reconciles versions and updates packages.
/// - Parameters:
///   - application: `Application` object for database, client, and logger access
///   - packages: packages to be analysed
/// - Returns: future
func analyze(application: Application, packages: [Package]) -> EventLoopFuture<Void> {
    AppMetrics.analyzeCandidatesCount?.set(packages.count)
    // get or create directory
    let checkoutDir = Current.fileManager.checkoutsDirectory()
    application.logger.info("Checkout directory: \(checkoutDir)")
    if !Current.fileManager.fileExists(atPath: checkoutDir) {
        application.logger.info("Creating checkouts directory at path: \(checkoutDir)")
        do {
            try Current.fileManager.createDirectory(atPath: checkoutDir,
                                                    withIntermediateDirectories: false,
                                                    attributes: nil)
        } catch {
            let msg = "Failed to create checkouts directory: \(error.localizedDescription)"
            return Current.reportError(application.client,
                                       .critical,
                                       AppError.genericError(nil, msg))
        }
    }
    
    let packageUpdates = refreshCheckouts(application: application, packages: packages)
        .flatMap { updateRepositories(application: application, packages: $0) }
    
    let versionUpdates = packageUpdates.flatMap { packages in
        application.db.transaction { tx -> EventLoopFuture<[Result<Package, Error>]> in
            let versions = reconcileVersions(client: application.client,
                                             logger: application.logger,
                                             threadPool: application.threadPool,
                                             transaction: tx,
                                             packages: packages)
            return versions
                .map { getManifests(logger: application.logger, versions: $0) }
                .flatMap { updateVersionsAndProducts(on: tx, packages: $0) }
                .flatMap { updateLatestVersions(on: tx, packages: $0) }
        }
    }
    
    let statusOps = versionUpdates.flatMap { updatePackage(application: application,
                                                           results: $0,
                                                           stage: .analysis) }
    
    let materializedViewRefresh = statusOps
        .flatMap { RecentPackage.refresh(on: application.db) }
        .flatMap { RecentRelease.refresh(on: application.db) }
        .flatMap { Search.refresh(on: application.db) }
        .flatMap { Stats.refresh(on: application.db) }
    
    return materializedViewRefresh
}


/// Refresh git checkouts (working copies) for a list of packages.
/// - Parameters:
///   - application: `Application` object for database, client, and logger access
///   - packages: list of `Packages`
/// - Returns: future with `Result`s
func refreshCheckouts(application: Application, packages: [Package]) -> EventLoopFuture<[Result<Package, Error>]> {
    let ops = packages.map { refreshCheckout(application: application, package: $0) }
    return EventLoopFuture.whenAllComplete(ops, on: application.eventLoopGroup.next())
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
///   - application: `Application` object
///   - package: `Package` to refresh
/// - Returns: future
func refreshCheckout(application: Application, package: Package) -> EventLoopFuture<Package> {
    guard let cacheDir = Current.fileManager.cacheDirectoryPath(for: package) else {
        return application.eventLoopGroup.next().makeFailedFuture(
            AppError.invalidPackageCachePath(package.id, package.url)
        )
    }
    return application.threadPool.runIfActive(eventLoop: application.eventLoopGroup.next()) {
        guard Current.fileManager.fileExists(atPath: cacheDir) else {
            try clone(logger: application.logger, cacheDir: cacheDir, url: package.url)
            return
        }

        // attempt to fetch - if anything goes wrong we delete the directory
        // and fall back to cloning
        do {
            try fetch(logger: application.logger,
                      cacheDir: cacheDir,
                      branch: package.repository?.defaultBranch ?? "master",
                      url: package.url)
        } catch {
            application.logger.info("fetch failed: \(error.localizedDescription)")
            application.logger.info("removing directory")
            try Current.shell.run(command: .removeFile(from: cacheDir, arguments: ["-r", "-f"]))
            try clone(logger: application.logger, cacheDir: cacheDir, url: package.url)
        }
    }
    .map { package }
}


/// Update the `Repository`s of a given set of `Package`s with git repository data (commit count, first commit date, etc).
/// - Parameters:
///   - application: `Application` object
///   - packages: `Package`s to update
/// - Returns: results future
func updateRepositories(application: Application,
                        packages: [Result<Package, Error>]) -> EventLoopFuture<[Result<Package, Error>]> {
    let ops = packages.map { result -> EventLoopFuture<Package> in
        let updatedPackage = result.flatMap(updateRepository(package:))
        switch updatedPackage {
            case .success(let pkg):
                AppMetrics.analyzeUpdateRepositorySuccessTotal?.inc()
                return pkg.repositories.update(on: application.db).transform(to: pkg)
            case .failure(let error):
                AppMetrics.analyzeUpdateRepositoryFailureTotal?.inc()
                return application.eventLoopGroup.future(error: error)
        }
    }
    return EventLoopFuture.whenAllComplete(ops, on: application.eventLoopGroup.next())
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
        repo.commitCount = try Git.commitCount(at: gitDirectory)
        repo.firstCommitDate = try Git.firstCommitDate(at: gitDirectory)
        repo.lastCommitDate = try Git.lastCommitDate(at: gitDirectory)
        return package
    }
}


/// Reconcile versions for a set of `Package`s. This will add new versions and delete versions that have been removed based on a comparison of their immutable references - the pair (`Reference`, `CommitHash`) of each version.
/// - Parameters:
///   - client: `Client` object (for Rollbar error reporting)
///   - logger: `Logger` object
///   - threadPool: `NIOThreadPool` (for running `git tag` commands)
///   - transaction: database transaction
///   - packages: `Package`s to reconcile
/// - Returns: results future
func reconcileVersions(client: Client,
                       logger: Logger,
                       threadPool: NIOThreadPool,
                       transaction: Database,
                       packages: [Result<Package, Error>]) -> EventLoopFuture<[Result<(Package, [Version]), Error>]> {
    let ops = packages.map { result -> EventLoopFuture<(Package, [Version])> in
        switch result {
            case .success(let pkg):
                return reconcileVersions(client: client,
                                         logger: logger,
                                         threadPool: threadPool,
                                         transaction: transaction,
                                         package: pkg)
                    .map { (pkg, $0) }
            case .failure(let error):
                return transaction.eventLoop.future(error: error)
        }
    }
    return EventLoopFuture.whenAllComplete(ops, on: transaction.eventLoop)
}


/// Reconcile versions for a given `Package`. This will add new versions and delete versions that have been removed based on a comparison of their immutable references - the pair (`Reference`, `CommitHash`) of each version.
/// - Parameters:
///   - client: `Client` object (for Rollbar error reporting)
///   - logger: `Logger` object
///   - threadPool: `NIOThreadPool` (for running `git tag` commands)
///   - transaction: database transaction
///   - package: `Package` to reconcile
/// - Returns: future with array of inserted `Version`s
func reconcileVersions(client: Client,
                       logger: Logger,
                       threadPool: NIOThreadPool,
                       transaction: Database,
                       package: Package) -> EventLoopFuture<[Version]> {
    guard let cacheDir = Current.fileManager.cacheDirectoryPath(for: package) else {
        return transaction.eventLoop.future(error: AppError.invalidPackageCachePath(package.id, package.url))
    }
    guard let pkgId = package.id else {
        return transaction.eventLoop.future(error: AppError.genericError(nil, "PANIC: package id nil for package \(package.url)"))
    }
    
    let defaultBranch = Repository.defaultBranch(on: transaction, for: package)
        .map { b -> [Reference] in
            if let b = b { return [.branch(b)] } else { return [] }  // drop nil default branch
        }
    
    let tags: EventLoopFuture<[Reference]> = threadPool.runIfActive(eventLoop: transaction.eventLoop) {
        logger.info("listing tags for package \(package.url)")
        return try Git.tag(at: cacheDir)
    }
    .flatMapError {
        let appError = AppError.genericError(pkgId, "Git.tag failed: \($0.localizedDescription)")
        logger.report(error: appError)
        return Current.reportError(client, .error, appError)
            .transform(to: [])
    }
    
    let references = defaultBranch.and(tags).map { $0 + $1 }
    let incoming: EventLoopFuture<[Version]> = references
        .flatMapEachThrowing { ref in
            let revInfo = try Git.revisionInfo(ref, at: cacheDir)
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
        .flatMap { delta in
            applyVersionDelta(on: transaction, delta: delta)
                .map { delta.toAdd }
        }
}


/// Saves and deletes the versions specified in the version delta parameter.
/// - Parameters:
///   - transaction: transaction to run the save and delete in
///   - delta: tuple containing the version to add and remove
/// - Returns: future
func applyVersionDelta(on transaction: Database,
                       delta: (toAdd: [Version], toDelete: [Version])) -> EventLoopFuture<Void> {
    let delete = delta.toDelete.delete(on: transaction)
    let insert = delta.toAdd.create(on: transaction)
    delta.toAdd.forEach {
        AppMetrics.analyzeVersionsAddedTotal?.inc(1, .init($0.reference))
    }
    delta.toDelete.forEach {
        AppMetrics.analyzeVersionsDeletedTotal?.inc(1, .init($0.reference))
    }
    return delete.flatMap { insert }
}


/// Get the package manifests for a set of `Package`s.
/// - Parameters:
///   - logger: `Logger` object
///   - versions: `Result` containing the `Package` and the set of `Verion`s to analyse
/// - Returns: results future including the `Manifest`s
func getManifests(logger: Logger,
                  versions: [Result<(Package, [Version]), Error>]) -> [Result<(Package, [(Version, Manifest)]), Error>] {
    versions.map { result -> Result<(Package, [(Version, Manifest)]), Error> in
        result.flatMap { (pkg, versions) -> Result<(Package, [(Version, Manifest)]), Error> in
            let m = versions.map { getManifest(package: pkg, version: $0) }
            let successes = m.compactMap { try? $0.get() }
            let errors = m.compactMap { $0.getError() }
                .map { AppError.genericError(pkg.id, "getManifests failed: \($0.localizedDescription)") }
            errors.forEach { logger.report(error: $0) }
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


/// Persist version and product changes to the database.
/// - Parameters:
///   - database: `Database` object
///   - results: packages to save
/// - Returns: results future
func updateVersionsAndProducts(on database: Database,
                               packages: [Result<(Package, [(Version, Manifest)]), Error>]) -> EventLoopFuture<[Result<Package, Error>]> {
    let ops = packages.map { result -> EventLoopFuture<Package> in
        switch result {
            case let .success((pkg, versionsAndManifests)):
                let updates = versionsAndManifests.map { version, manifest in
                    updateVersion(on: database, version: version, manifest: manifest)
                        .flatMap { createProducts(on: database, version: version, manifest: manifest)}
                }
                return EventLoopFuture
                    .andAllComplete(updates, on: database.eventLoop)
                    .transform(to: pkg)
                
            case let .failure(error):
                return database.eventLoop.future(error: error)
        }
    }
    return EventLoopFuture.whenAllComplete(ops, on: database.eventLoop)
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


/// Create and persist `Product`s for a given `Version` according to the given `Manifest`.
/// - Parameters:
///   - database: `Database` object
///   - version: version to update
///   - manifest: `Manifest` data
/// - Returns: future
func createProducts(on database: Database, version: Version, manifest: Manifest) -> EventLoopFuture<Void> {
    let products = manifest.products.compactMap { p -> Product? in
        let type: Product.`Type`
        switch p.type {
            case .executable: type = .executable
            case .library:    type = .library
        }
        // Using `try?` here because the only way this could error is version.id being nil
        // - that should never happen and even in the pathological case we can skip the product
        return try? Product(version: version, type: type, name: p.name)
    }
    return products.create(on: database)
}


/// Update the significant versions (stable, beta, latest) for a set of `Package`s.
/// - Parameters:
///   - database: `Database` object
///   - packages: packages to update
/// - Returns: results future
func updateLatestVersions(on database: Database,
                          packages: [Result<Package, Error>]) -> EventLoopFuture<[Result<Package, Error>]> {
    let ops = packages.map { result -> EventLoopFuture<Package> in
        switch result {
            case let .success(pkg):
                return updateLatestVersions(on: database, package: pkg)
            case let .failure(error):
                return database.eventLoop.future(error: error)
        }
    }
    return EventLoopFuture.whenAllComplete(ops, on: database.eventLoop)
}


/// Update the significant versions (stable, beta, latest) for a given `Package`.
/// - Parameters:
///   - database: `Database` object
///   - package: package to update
/// - Returns: `Package` future
func updateLatestVersions(on database: Database,
                          package: Package) -> EventLoopFuture<Package> {
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
                .map { package }
        }
}
