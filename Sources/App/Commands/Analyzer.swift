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

    // pull or clone repos
    let checkouts = refreshCheckouts(application: application, limit: limit)

    return checkouts.transform(to: ())
}


func refreshCheckouts(application: Application, limit: Int) -> EventLoopFuture<[Result<Package, Error>]>  {
    Package.fetchUpdateCandidates(application.db, limit: limit)
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
