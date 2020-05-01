import Fluent
import Vapor
import ShellOut


struct AnalyzerCommand: Command {
    let defaultLimit = 1

    struct Signature: CommandSignature {
        @Option(name: "limit", short: "l")
        var limit: Int?
    }

    var help: String { "Run package analysis (fetching git repository and inspecting content)" }

    func run(using context: CommandContext, signature: Signature) throws {
        let limit = signature.limit ?? defaultLimit
        context.console.info("Analyzing (limit: \(limit)) ...")

        try analyze(application: context.application, limit: limit).wait()
    }
}


func analyze(application: Application, limit: Int) throws -> EventLoopFuture<Void> {
    // get or create directory
    let checkoutDir = application.directory.checkouts
    application.logger.info("Checkout directory: \(checkoutDir)")
    if !Current.fileManager.fileExists(atPath: checkoutDir) {
        application.logger.info("Creating checkout directory at path: \(checkoutDir)")
        try Current.fileManager.createDirectory(atPath: checkoutDir,
                                                  withIntermediateDirectories: false,
                                                  attributes: nil)
    }

    let checkouts = Package.fetchUpdateCandidates(application.db, limit: limit)
        .flatMapEach(on: application.eventLoopGroup.next()) { pkg in
            refreshCheckout(application: application, package: pkg)
    }

    // get versions
    let versions = checkouts
        .flatMapEach(on: application.eventLoopGroup.next()) { result -> EventLoopFuture<Void> in
            do {
                let pkg = try result.get()
                return try reconcileVersions(application: application, package: pkg)
            } catch {
                return application.eventLoopGroup.next().makeFailedFuture(error)
            }
    }
    return versions.transform(to: ())
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
    guard let path = application.directory.checkoutPath(for: package) else {
        throw AppError.invalidPackageUrl(package.id, package.url)
    }
    return application.threadPool.runIfActive(eventLoop: application.eventLoopGroup.next()) {
        if Current.fileManager.fileExists(atPath: path) {
            application.logger.info("pulling \(package.url) in \(path)")
            try Current.shell.run(command: .gitPull(), at: path)
        } else {
            application.logger.info("cloning \(package.url) to \(path)")
            try Current.shell.run(command: .gitClone(url: URL(string: package.url)!, to: path))
        }
        return package
    }
}


func reconcileVersions(application: Application, package: Package) throws -> EventLoopFuture<Void> {
    // fetch tags
    guard let path = application.directory.checkoutPath(for: package) else {
        throw AppError.invalidPackageUrl(package.id, package.url)
    }
    guard let pkgId = package.id else {
        throw AppError.genericError(nil, "PANIC: package id nil for package \(package.url)")
    }
    let tags: EventLoopFuture<[String]> = application.threadPool.runIfActive(eventLoop: application.eventLoopGroup.next()) {
        application.logger.info("listing tags for package \(package.url)")
        let tags = try Current.shell.run(command: .init(string: "git tag"), at: path)
        return tags.split(separator: "\n").map(String.init)
    }

    // first stab: delete ...
    let delete = Version.query(on: application.db)
        .filter(\.$package.$id == pkgId)
        .delete()
    // ... and insert
    let insert = tags
        .flatMapEachThrowing { try Version(package: package, tagName: $0)}
        .flatMap { $0.create(on: application.db) }

    return delete.flatMap { insert }
}


//func parseVersions(_ string: String) -> [SemVer] {
//    string.split(separator: "\n")
//        .map(String.init)
//        .compactMap(SemVer.init(string:))
//}
