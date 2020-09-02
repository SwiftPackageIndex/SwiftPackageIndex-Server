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
    }
}


func analyze(application: Application, id: Package.Id) -> EventLoopFuture<Void> {
    let packages = Package.query(on: application.db)
        .with(\.$repositories)
        .filter(\.$id == id)
        .first()
        .unwrap(or: Abort(.notFound))
        .map { [$0] }
    return analyze(application: application, packages: packages)
}


func analyze(application: Application, limit: Int) -> EventLoopFuture<Void> {
    let packages = Package.fetchCandidates(application.db, for: .analysis, limit: limit)
    return analyze(application: application, packages: packages)
}


func analyze(application: Application, packages: EventLoopFuture<[Package]>) -> EventLoopFuture<Void> {
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
    
    let checkouts = packages
        .flatMap { pullOrClone(application: application, packages: $0) }
        .flatMap { updateRepositories(application: application, checkouts: $0) }
    
    let versionUpdates = checkouts.flatMap { checkouts in
        application.db.transaction { tx -> EventLoopFuture<[Result<Package, Error>]> in
            let versions = reconcileVersions(client: application.client,
                                             logger: application.logger,
                                             threadPool: application.threadPool,
                                             transaction: tx,
                                             checkouts: checkouts)
            return versions
                .map { getManifests(logger: application.logger, versions: $0) }
                .flatMap { updateVersionsAndProducts(on: tx, results: $0) }
                .flatMap { updateLatestVersions(on: tx, results: $0) }
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


func pullOrClone(application: Application, packages: [Package]) -> EventLoopFuture<[Result<Package, Error>]> {
    let ops = packages.map { pullOrClone(application: application, package: $0) }
    return EventLoopFuture.whenAllComplete(ops, on: application.eventLoopGroup.next())
}


func pullOrClone(application: Application, package: Package) -> EventLoopFuture<Package> {
    guard let cacheDir = Current.fileManager.cacheDirectoryPath(for: package) else {
        return application.eventLoopGroup.next().makeFailedFuture(
            AppError.invalidPackageCachePath(package.id, package.url)
        )
    }
    return application.threadPool.runIfActive(eventLoop: application.eventLoopGroup.next()) {
        if Current.fileManager.fileExists(atPath: cacheDir) {
            do {  // attempt to fetch - if anything goes wrong we delete the directory and clone
                application.logger.info("pulling \(package.url) in \(cacheDir)")
                // clean up stray lock files that might have remained from aborted commands
                try ["HEAD.lock", "index.lock"].forEach { fileName in
                    let filePath = cacheDir + "/.git/\(fileName)"
                    if Current.fileManager.fileExists(atPath: filePath) {
                        application.logger.info("Removing stale \(fileName) at path: \(filePath)")
                        try Current.shell.run(command: .removeFile(from: filePath))
                    }
                }
                // git reset --hard to deal with stray .DS_Store files on macOS
                try Current.shell.run(command: .init(string: "git reset --hard"), at: cacheDir)
                try Current.shell.run(command: .init(string: "git clean -fdx"), at: cacheDir)
                try Current.shell.run(command: .init(string: "git fetch --tags"), at: cacheDir)
                let branch = package.repository?.defaultBranch ?? "master"
                try Current.shell.run(command: .gitCheckout(branch: branch), at: cacheDir)
                try Current.shell.run(command: .init(string: #"git reset "origin/\#(branch)" --hard"#),
                                      at: cacheDir)
            } catch {
                application.logger.info("checkout failed: \(error.localizedDescription)")
                application.logger.info("removing directory and re-cloning")
                try Current.shell.run(command: .removeFile(from: cacheDir, arguments: ["-r", "-f"]))
                try Current.shell.run(command: .gitClone(url: URL(string: package.url)!, to: cacheDir),
                                      at: Current.fileManager.checkoutsDirectory())
            }
        } else {
            application.logger.info("cloning \(package.url) to \(cacheDir)")
            try Current.shell.run(command: .gitClone(url: URL(string: package.url)!, to: cacheDir),
                                  at: Current.fileManager.checkoutsDirectory())
        }
        return package
    }
}


func updateRepositories(application: Application,
                        checkouts: [Result<Package, Error>]) -> EventLoopFuture<[Result<Package, Error>]> {
    let ops = checkouts.map { checkout -> EventLoopFuture<Package> in
        let updatedPackage = checkout.flatMap(updateRepository(package:))
        switch updatedPackage {
            case .success(let pkg):
                return pkg.repositories.update(on: application.db).transform(to: pkg)
            case .failure(let error):
                return application.eventLoopGroup.future(error: error)
        }
    }
    return EventLoopFuture.whenAllComplete(ops, on: application.eventLoopGroup.next())
}


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


func reconcileVersions(client: Client,
                       logger: Logger,
                       threadPool: NIOThreadPool,
                       transaction: Database,
                       checkouts: [Result<Package, Error>]) -> EventLoopFuture<[Result<(Package, [Version]), Error>]> {
    let ops = checkouts.map { checkout -> EventLoopFuture<(Package, [Version])> in
        switch checkout {
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
            return try Version(package: package,
                               commit: revInfo.commit,
                               commitDate: revInfo.date,
                               reference: ref) }
    
    return Version.query(on: transaction)
        .filter(\.$package.$id == pkgId)
        .all()
        .and(incoming)
        .flatMap { saved, incoming -> EventLoopFuture<[Version]> in
            let delta = Version.diff(local: saved, incoming: incoming)
            let delete = delta.toDelete.delete(on: transaction)
            let insert = delta.toAdd.create(on: transaction).transform(to: delta.toAdd)
            return delete.flatMap { insert }
        }
}


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


func dumpPackage(at path: String, versionId: Version.Id?) throws -> Manifest {
    guard Current.fileManager.fileExists(atPath: path + "/Package.swift") else {
        // It's important to check for Package.swift - otherwise `dump-package` will go
        // up the tree through parent directories to find one
        throw AppError.invalidRevision(versionId, "no Package.swift")
    }
    let swiftCommand = Current.fileManager.fileExists("/swift-5.3/usr/bin/swift")
        ? "/swift-5.3/usr/bin/swift"
        : "swift"
    let json = try Current.shell.run(command: .init(string: "\(swiftCommand) package dump-package"),
                                     at: path)
    return try JSONDecoder().decode(Manifest.self, from: Data(json.utf8))
}


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

        let manifest = try dumpPackage(at: cacheDir, versionId: version.id)

        return (version, manifest)
    }
}


func updateVersionsAndProducts(on database: Database,
                               results: [Result<(Package, [(Version, Manifest)]), Error>]) -> EventLoopFuture<[Result<Package, Error>]> {
    let ops = results.map { result -> EventLoopFuture<Package> in
        switch result {
            case let .success((pkg, versionsAndManifests)):
                let updates = versionsAndManifests.map { version, manifest in
                    updateVersion(on: database, version: version, manifest: manifest)
                        .flatMap { updateProducts(on: database, version: version, manifest: manifest)}
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


func updateVersion(on database: Database, version: Version, manifest: Manifest) -> EventLoopFuture<Void> {
    version.packageName = manifest.name
    version.swiftVersions = manifest.swiftLanguageVersions?.compactMap(SwiftVersion.init) ?? []
    version.supportedPlatforms = manifest.platforms?.compactMap(Platform.init(from:)) ?? []
    return version.save(on: database)
}


func updateProducts(on database: Database, version: Version, manifest: Manifest) -> EventLoopFuture<Void> {
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


func updateLatestVersions(on database: Database,
                          results: [Result<Package, Error>]) -> EventLoopFuture<[Result<Package, Error>]> {
    let ops = results.map { result -> EventLoopFuture<Package> in
        switch result {
            case let .success(pkg):
                return updateLatestVersions(on: database, package: pkg)
            case let .failure(error):
                return database.eventLoop.future(error: error)
        }
    }
    return EventLoopFuture.whenAllComplete(ops, on: database.eventLoop)
}


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
