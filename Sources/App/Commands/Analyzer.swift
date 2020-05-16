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

    let checkouts = packages.flatMap { pullOrClone(application: application, packages: $0) }

    let versions = checkouts.flatMap { reconcileVersions(application: application, checkouts: $0) }

    let versionsAndManifests = versions.map(getManifests)

    let updateOps = versionsAndManifests.flatMap { updateVersionsAndProducts(on: application.db,
                                                                             results: $0) }

    let statusOps = updateOps.flatMap { updateStatus(application: application,
                                                     results: $0,
                                                     stage: .analysis) }

    return statusOps
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
            application.logger.info("pulling \(package.url) in \(cacheDir)")
            // git reset --hard to deal with stray .DS_Store files on macOS
            try Current.shell.run(command: .init(string: "git reset --hard"), at: cacheDir)
            let branch = package.repository?.defaultBranch ?? "master"
            try Current.shell.run(command: .gitCheckout(branch: branch), at: cacheDir)
            try Current.shell.run(command: .gitPull(), at: cacheDir)
        } else {
            application.logger.info("cloning \(package.url) to \(cacheDir)")
            let wdir = Current.fileManager.checkoutsDirectory()
            try Current.shell.run(command: .gitClone(url: URL(string: package.url)!, to: cacheDir), at: wdir)
        }
        return package
    }
}


func reconcileVersions(application: Application, checkouts: [Result<Package, Error>]) -> EventLoopFuture<[Result<(Package, [Version]), Error>]> {
    let ops = checkouts.map { checkout -> EventLoopFuture<(Package, [Version])> in
        switch checkout {
            case .success(let pkg):
                return reconcileVersions(application: application, package: pkg)
                    .map { (pkg, $0) }
            case .failure(let error):
                return application.eventLoopGroup.future(error: error)
        }
    }
    return EventLoopFuture.whenAllComplete(ops, on: application.eventLoopGroup.next())
}


func reconcileVersions(application: Application, package: Package) -> EventLoopFuture<[Version]> {
    // fetch tags
    guard let cacheDir = Current.fileManager.cacheDirectoryPath(for: package) else {
        return application.eventLoopGroup.next().makeFailedFuture(
            AppError.invalidPackageCachePath(package.id, package.url)
        )
    }
    guard let pkgId = package.id else {
        return application.eventLoopGroup.next().makeFailedFuture(
            AppError.genericError(nil, "PANIC: package id nil for package \(package.url)")
        )
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
            .compactMap(SemVer.init)
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


func getManifests(versions: [Result<(Package, [Version]), Error>]) -> [Result<(Package, [(Version, Manifest)]), Error>] {
    versions.map { (r: Result<(Package, [Version]), Error>) -> Result<(Package, [(Version, Manifest)]), Error> in

        r.flatMap { (pkg, versions) -> Result<(Package, [(Version, Manifest)]), Error> in
            let m = versions.map { getManifest(package: pkg, version: $0) }
            let successes = m.compactMap { try? $0.get() }
            // TODO: report errors (need client and database)
            //            let errors = m.compactMap { $0.getError() }
            //            errors.map { Current.reportError(client: client, database: database, error: $0, stage: .analysis) }
            guard !successes.isEmpty else { return .failure(AppError.noValidVersions(pkg.id, pkg.url)) }
            return .success((pkg, successes))
        }
    }
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
        guard Current.fileManager.fileExists(atPath: cacheDir + "/Package.swift") else {
            // It's important to check for Package.swift - otherwise `dump-package` will go
            // up the tree through parent directories to find one
            throw AppError.invalidRevision(version.id, "no Package.swift")
        }
        let json = try Current.shell.run(command: .init(string: "swift package dump-package"), at: cacheDir)
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(json.utf8))
        return (version, manifest)
    }
}


func updateVersionsAndProducts(on database: Database, results: [Result<(Package, [(Version, Manifest)]), Error>]) -> EventLoopFuture<[Result<Package, Error>]> {
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
    version.swiftVersions = manifest.swiftLanguageVersions ?? []
    version.supportedPlatforms = manifest.platforms?.compactMap { Platform(from: $0) } ?? []
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
