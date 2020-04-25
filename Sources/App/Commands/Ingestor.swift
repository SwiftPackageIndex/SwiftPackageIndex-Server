import Vapor
import Fluent

let masterPackageListURL = URI(string: "https://raw.githubusercontent.com/daveverwer/SwiftPMLibrary/master/packages.json")

enum IngestorError: Error {
    case recordNotFound
}

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
