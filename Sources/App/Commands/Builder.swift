import Fluent
import Vapor


struct BuilderCommand: Command {
    let defaultLimit = 1

    struct Signature: CommandSignature {
        @Option(name: "limit", short: "l")
        var limit: Int?
    }

    var help: String { "Trigger package builds" }

    func run(using context: CommandContext, signature: Signature) throws {
        let limit = signature.limit ?? defaultLimit

        context.console.info("Triggering builds (limit: \(limit) ...")
        let request = try triggerBuilds(application: context.application, limit: limit)
        try request.wait()
    }
}


func triggerBuilds(application: Application, limit: Int) throws -> EventLoopFuture<Void> {
    application.eventLoopGroup.next().future()
}
