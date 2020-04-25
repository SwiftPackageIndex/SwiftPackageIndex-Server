import Vapor
import Fluent


struct IngestorCommand: Command {
    struct Signature: CommandSignature {
        @Option(name: "limit", short: "l")
        var limit: Int?
    }

    var help: String {
        "Ingests packages"
    }

    func run(using context: CommandContext, signature: Signature) throws {
        //        let limit = signature.limit
        context.console.print("Ingesting ...")

    }

}
