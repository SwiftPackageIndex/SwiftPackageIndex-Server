import Vapor


struct DeleteBuildsCommand: Command {
    struct Signature: CommandSignature {
        @Option(name: "version-id", short: "v")
        var versionId: UUID?
    }

    var help: String { "Delete build records" }

    func run(using context: CommandContext, signature: Signature) throws {

        if let versionId = signature.versionId {
            context.console.info("Deleting builds for version id \(versionId) ...")
            let count = try Build.delete(on: context.application.db, versionId: versionId).wait()
            context.console.info("Deleted \(pluralizedCount(count, singular: "record"))")
        }
    }
}
