import Fluent
import Vapor
import ShellOut


struct InspectorCommand: Command {
    let defaultLimit = 1

    struct Signature: CommandSignature {
        @Option(name: "limit", short: "l")
        var limit: Int?
    }

    var help: String { "Run package inspection (fetching git repository and inspecting content)" }

    func run(using context: CommandContext, signature: Signature) throws {
        let limit = signature.limit ?? defaultLimit
        context.console.info("Inspecting (limit: \(limit)) ...")

        try inspect(application: context.application, limit: limit).wait()
    }
}


func inspect(application: Application, limit: Int) throws -> EventLoopFuture<Void> {
    // get or create directory
    let checkoutDir = application.directory.checkouts
    if !FileManager.default.fileExists(atPath: checkoutDir) {
        application.logger.info("Creating checkouts directory at path: \(checkoutDir)")
        try FileManager.default.createDirectory(atPath: checkoutDir,
                                                withIntermediateDirectories: false,
                                                attributes: nil)
    }

    // pull or clone repos
    let checkouts = refreshCheckouts(application: application, limit: limit)

    return checkouts.transform(to: ())
}


func refreshCheckouts(application: Application, limit: Int) -> EventLoopFuture<[Result<Package, Error>]>  {
    Package.query(on: application.db)
        .updateCandidates(limit: limit)
        .flatMapEach(on: application.db.eventLoop) { pkg in
            do {
                return try pullOrClone(application: application, package: pkg)
                    .map { .success($0) }
                    .flatMapErrorThrowing { .failure($0) }
            } catch {
                return application.db.eventLoop.makeSucceededFuture(.failure(error))
            }
    }
}


func pullOrClone(application: Application, package: Package) throws -> EventLoopFuture<Package> {
    guard let basename = package.localCacheDirectory else {
        throw AppError.invalidPackageUrl(package.id, package.url)
    }
    let path = application.directory.checkouts + "/" + basename
    let promise = application.eventLoopGroup.next().makePromise(of: Package.self)
    application.threadPool.submit { _ in
        do {
            if FileManager.default.fileExists(atPath: path) {
                application.logger.info("pulling \(package.url) in \(path)")
                try shellOut(to: .gitPull(), at: path)
            } else {
                application.logger.info("cloning \(package.url) to \(path)")
                try shellOut(to: .gitClone(url: URL(string: package.url)!, to: path))
            }
            promise.succeed(package)
        } catch {
            application.logger.error("Clone/pull failed for package \(package.url): \(error.localizedDescription)")
            promise.fail(error)
        }
    }
    return promise.futureResult
}
