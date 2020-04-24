import Vapor


struct IngestorCommand: Command {
    struct Signature: CommandSignature { }

    var help: String {
        "Ingests packages"
    }

    func run(using context: CommandContext, signature: Signature) throws {
        context.console.print("ingestor")
    }

}