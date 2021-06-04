import Backtrace
import Fluent
import ShellOut
import Vapor

struct CrashCommand: Command {
    struct Signature: CommandSignature {
        @Flag(name: "backtrace", short: "b", help: "installs Backtrace crash handler before crashing")
        var backtrace: Bool
        
        @Option(name: "reason", short: "r", help: "specifies fatal error reason")
        var reason: String?
    }

    var help: String { "Intentionally crashes the app" }

    func run(using _: CommandContext, signature: Signature) throws {
        if signature.backtrace {
            Backtrace.install()
        }
        
        fatalError(signature.reason ?? "Intentionally crashing the app")
    }
}
