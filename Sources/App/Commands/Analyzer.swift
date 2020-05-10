import Fluent
import Vapor
import ShellOut


struct AnalyzerCommand: Command {
    let defaultLimit = 1

    struct Signature: CommandSignature {
        @Option(name: "limit", short: "l")
        var limit: Int?
        @Option(name: "id")
        var id: String?
    }

    var help: String { "Run package analysis (fetching git repository and inspecting content)" }

    func run(using context: CommandContext, signature: Signature) throws {
        let limit = signature.limit ?? defaultLimit
        let id = signature.id.flatMap(UUID.init(uuidString:))
        if let id = id {
            context.console.info("Analyzing (id: \(id)) ...")
            try analyze(application: context.application, id: id).wait()
        } else {
            context.console.info("Analyzing (limit: \(limit)) ...")
            try analyze(application: context.application, limit: limit).wait()
        }
    }
}


func analyze(application: Application, id: Package.Id) throws -> EventLoopFuture<Void> {
    let packages = Package.query(on: application.db)
        .with(\.$repositories)
        .filter(\.$id == id)
        .first()
        .unwrap(or: Abort(.notFound))
        .map { [$0] }
    return try analyze(application: application, packages: packages)
}


func analyze(application: Application, limit: Int) throws -> EventLoopFuture<Void> {
    let packages = Package.fetchCandidates(application.db, for: .analysis, limit: limit)
    return try analyze(application: application, packages: packages)
}


func analyze(application: Application, packages: EventLoopFuture<[Package]>) throws -> EventLoopFuture<Void> {
    // get or create directory
    let checkoutDir = Current.fileManager.checkoutsDirectory
    application.logger.info("Checkout directory: \(checkoutDir)")
    if !Current.fileManager.fileExists(atPath: checkoutDir) {
        application.logger.info("Creating checkout directory at path: \(checkoutDir)")
        try Current.fileManager.createDirectory(atPath: checkoutDir,
                                                  withIntermediateDirectories: false,
                                                  attributes: nil)
    }

    let checkouts = packages
        .flatMapEach(on: application.eventLoopGroup.next()) { pkg in
            refreshCheckout(application: application, package: pkg)
    }

    // reconcile versions
    let packageAndVersions = checkouts
        .flatMapEach(on: application.eventLoopGroup.next()) {
            reconcileVersions(application: application, result: $0)
    }

    let versionUpdates = packageAndVersions
        .mapEach { (pkg, versions) -> (Package, [EventLoopFuture<Void>]) in
            let res = versions
                .map { ($0, getManifest(package: pkg, version: $0)) }
                .map {
                    updateVersion(on: application.db, version: $0, manifest: $1)
                        .flatMap { updateProducts(on: application.db, version: $0, manifest: $1) }
            }
            return (pkg, res)
    }

    // FIXME: sas 2020-05-04: Workaround for partial flush described here:
    // https://discordapp.com/channels/431917998102675485/444249946808647699/706796431540748372
    // FIXME: this breaks exposing this via the API:
    // Precondition failed: BUG DETECTED: wait() must not be called when on an EventLoop.
    let fulfilledUpdates = try versionUpdates.wait()
    let setStatus = fulfilledUpdates.map { (pkg, updates) -> EventLoopFuture<[Void]> in
        if updates.isEmpty {
            // Make sure we mark pkg as updated even if it has no versions - we don't want to
            // get stuck reprocessing it all the time
            pkg.status = .ok
            pkg.processingStage = .analysis
            return pkg.update(on: application.db).map { [] }
        } else {
            return EventLoopFuture.whenAllComplete(updates, on: application.db.eventLoop)
                .flatMapEach(on: application.db.eventLoop) { result -> EventLoopFuture<Void> in
                    switch result {
                        case .success:
                            pkg.status = .ok
                        case .failure(let error):
                            application.logger.error("Analysis error: \(error.localizedDescription)")
                            pkg.status = .analysisFailed
                    }
                    pkg.processingStage = .analysis
                    return pkg.save(on: application.db)
            }
        }
    }.flatten(on: application.db.eventLoop)

    return setStatus.transform(to: ())
}


func refreshCheckout(application: Application, package: Package) -> EventLoopFuture<Result<Package, Error>>  {
    do {
        return try pullOrClone(application: application, package: package)
            .map { .success($0) }
            .flatMapErrorThrowing { .failure($0) }
    } catch {
        return application.eventLoopGroup.next().makeSucceededFuture(.failure(error))
    }
}


func pullOrClone(application: Application, package: Package) throws -> EventLoopFuture<Package> {
    guard let cacheDir = Current.fileManager.cacheDirectoryPath(for: package) else {
        throw AppError.invalidPackageCachePath(package.id, package.url)
    }
    return application.threadPool.runIfActive(eventLoop: application.eventLoopGroup.next()) {
        if Current.fileManager.fileExists(atPath: cacheDir) {
            application.logger.info("pulling \(package.url) in \(cacheDir)")
            // git reset --hard to deal with stray .DS_Store files on macOS
            try Current.shell.run(command: .init(string: "git reset --hard"), at: cacheDir)
            let branch = package.repository?.defaultBranch ?? "master"
            try Current.shell.run(command: .gitCheckout(branch: branch), at: cacheDir)
            try Current.shell.run(command: .gitPull(allowingPrompt: false), at: cacheDir)
        } else {
            application.logger.info("cloning \(package.url) to \(cacheDir)")
            let wdir = Current.fileManager.checkoutsDirectory
            try Current.shell.run(command: .gitClone(url: URL(string: package.url)!, to: cacheDir, allowingPrompt: false), at: wdir)
        }
        return package
    }
}


/// Wrapper around _reconcileVersions to create a non-throwing version (mainly to ensure
/// that failed futures don't slip through and break the pipeline).
func reconcileVersions(application: Application, result: Result<Package, Error>) -> EventLoopFuture<(Package, [Version])> {
    do {
        let pkg = try result.get()
        return try _reconcileVersions(application: application, package: pkg)
            .map { (pkg, $0) }
    } catch {
        return application.eventLoopGroup.next().makeFailedFuture(error)
    }
}


func _reconcileVersions(application: Application, package: Package) throws -> EventLoopFuture<[Version]> {
    // fetch tags
    guard let cacheDir = Current.fileManager.cacheDirectoryPath(for: package) else {
        throw AppError.invalidPackageCachePath(package.id, package.url)
    }
    guard let pkgId = package.id else {
        throw AppError.genericError(nil, "PANIC: package id nil for package \(package.url)")
    }

    let defaultBranch = Repository.defaultBranch(on: application.db, for: package)
        .map { b -> [Reference] in
            if let b = b { return [.branch(b)] } else { return [] }  // drop nil default branch
        }

    let tags: EventLoopFuture<[Reference]> = application.threadPool.runIfActive(eventLoop: application.eventLoopGroup.next()) {
        application.logger.info("listing tags for package \(package.url)")
        let tags = try Current.shell.run(command: .init(string: "git tag"), at: cacheDir)
        return tags.split(separator: "\n")
            .map(String.init)
            .filter(SemVer.isValid)
            .map { Reference.tag($0) }
    }

    let references = defaultBranch.and(tags).map { $0 + $1 }

    // Delete ...
    let delete = Version.query(on: application.db)
        .filter(\.$package.$id == pkgId)
        .delete()
    // ... and insert versions
    let insert: EventLoopFuture<[Version]> = references
        .flatMapEachThrowing { try Version(package: package, reference: $0) }
        .flatMap { versions in
            versions.create(on: application.db)
                .map { versions }
        }

    return delete.flatMap { insert }
}


func getManifest(package: Package, version: Version) -> Result<Manifest, Error> {
    Result {
        // check out version in cache directory
        guard let cacheDir = Current.fileManager.cacheDirectoryPath(for: package) else {
            throw AppError.invalidPackageCachePath(package.id, package.url)
        }
        guard let reference = version.reference else {
            throw AppError.invalidRevision(version.id, nil)
        }
        try Current.shell.run(command: .gitCheckout(branch: reference.description), at: cacheDir)
        guard Current.fileManager.fileExists(atPath: cacheDir + "/Package.swift") else {
            // It's important to check for Package.swift - otherwise `dump-package` will go
            // up the tree through parent directories to find one
            throw AppError.invalidRevision(version.id, "no Package.swift")
        }
        let json = try Current.shell.run(command: .init(string: "swift package dump-package"), at: cacheDir)
        return try JSONDecoder().decode(Manifest.self, from: Data(json.utf8))
    }
}


func updateVersion(on database: Database, version: Version, manifest: Result<Manifest, Error>) -> EventLoopFuture<(Version, Manifest)> {
    switch manifest {
        case .success(let manifest):
            version.packageName = manifest.name
            version.swiftVersions = manifest.swiftLanguageVersions ?? []
            version.supportedPlatforms = manifest.platforms?.map { $0.description } ?? []
            return version.save(on: database)
                .transform(to: (version, manifest))
        case .failure(let error):
            return database.eventLoop.makeFailedFuture(error)
    }
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
