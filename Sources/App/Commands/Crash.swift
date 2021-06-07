import Backtrace
import Fluent
import ShellOut
import Vapor

struct CrashCommand: Command {
    enum Reason: String, CaseIterable {
        case precondition
        case fatal
        case unwrap
    }
    
    struct Signature: CommandSignature {
        @Flag(name: "backtrace", short: "b", help: "installs Backtrace handler before crashing")
        var backtrace: Bool
        
        @Option(name: "reason", short: "r", help: "specifies crash reason: \(Reason.allCases)")
        var reason: Reason?
    }

    var help: String { "Intentionally crashes the app" }

    func run(using context: CommandContext, signature: Signature) throws {
        if signature.backtrace {
            context.console.info("Installing backtrace...")
            Backtrace.install()
        }
        
        let reason = signature.reason ?? .fatal
        
        switch reason {
        case .fatal:
            fatalError("Intentionally crashing the app with fatalError")
        case .precondition:
            precondition(false, "Intentionally crashing the app with precondition")
        case .unwrap:
            context.console.info("Intentionally crashing the app with force unwrap")
            let something: Int? = nil
            print(something!)
        }
    }
}

extension CrashCommand.Reason: LosslessStringConvertible {
    var description: String {
        rawValue
    }
    
    init?(_ description: String) {
        self.init(rawValue: description)
    }
}
