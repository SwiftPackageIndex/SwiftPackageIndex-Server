import Vapor


struct MigrateLogsCommand: Command {
    let defaultLimit = 1

    struct Signature: CommandSignature {
        @Option(name: "limit", short: "l")
        var limit: Int?

        @Option(name: "id", help: "build id")
        var id: Build.Id?
    }

    var help: String { "Migate logs to S3" }

    func run(using context: CommandContext, signature: Signature) throws {
        let limit = signature.limit ?? defaultLimit
        if let id = signature.id {
            context.console.info("Migrating logs (build id: \(id)) ...")
            try migrateLogs(application: context.application, id: id).wait()
        } else {
            context.console.info("Migrating logs (limit: \(limit)) ...")
            try migrateLogs(application: context.application, limit: limit).wait()
        }
    }

}


func migrateLogs(application: Application, id: Build.Id) -> EventLoopFuture<Void> {
    Build.find(id, on: application.db)
        .unwrap(or: Abort(.notFound))
        .flatMap {
            migrateLogs(application: application, builds: [$0])
        }
}


func migrateLogs(application: Application, limit: Int) -> EventLoopFuture<Void> {
    fetchMigrationCandidates(application: application, limit: limit)
        .flatMap { migrateLogs(application: application, builds: $0)}
}


func migrateLogs(application: Application, builds: [Build]) -> EventLoopFuture<Void> {
    application.eventLoopGroup.future()
}


func fetchMigrationCandidates(application: Application, limit: Int) -> EventLoopFuture<[Build]> {
    // FIXME: implement
    application.eventLoopGroup.future([])
}
