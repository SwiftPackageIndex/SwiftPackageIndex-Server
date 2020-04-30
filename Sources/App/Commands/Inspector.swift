import Fluent
import Vapor


struct InspectorCommand: Command {
    struct Signature: CommandSignature { }

    var help: String { "Run package inspection" }

    func run(using context: CommandContext, signature: Signature) throws {
        context.console.print("Inspecting ...")
    }
}
