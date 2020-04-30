import Fluent
import Vapor


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
    let checkoutDir = application.directory.workingDirectory + "SPI-checkouts"
    print(checkoutDir)
    if !FileManager.default.fileExists(atPath: checkoutDir) {
        application.logger.info("Creating checkouts directory at path: \(checkoutDir)")
        try FileManager.default.createDirectory(atPath: checkoutDir,
                                                withIntermediateDirectories: false,
                                                attributes: nil)
    }

    // fetch packages that need updating
    let checkouts = refreshCheckouts(database: application.db, limit: limit)


    // pull or clone repo

    return checkouts.transform(to: ())
}


func refreshCheckouts(database: Database, limit: Int) -> EventLoopFuture<[Result<Package, Error>]>  {
    Package.query(on: database)
        .updateCandidates(limit: limit)
        .flatMapEach(on: database.eventLoop) { pkg in
            do {
                return try pullOrClone(eventLoop: database.eventLoop, package: pkg)
                    .map { .success($0) }
                    .flatMapErrorThrowing { .failure($0) }
            } catch {
                return database.eventLoop.makeSucceededFuture(.failure(error))
            }
    }
}


func pullOrClone(eventLoop: EventLoop, package: Package) throws -> EventLoopFuture<Package> {
    print("🚧 pulling \(package.url)")
    return eventLoop.makeSucceededFuture(package)
}
