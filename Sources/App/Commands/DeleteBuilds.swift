import Vapor


struct DeleteBuildsCommand: Command {
    struct Signature: CommandSignature {
        @Option(name: "version-id", short: "v")
        var versionId: UUID?
        @Option(name: "package-id", short: "p")
        var packageId: UUID?
        @Option(name: "latest", short: "l", help: "release, pre_release, or default_branch")
        var latest: Version.Kind?
    }

    var help: String { "Delete build records" }

    func run(using context: CommandContext, signature: Signature) throws {

        switch (signature.versionId, signature.packageId) {
            case let (versionId?, .none):
                context.console.info("Deleting builds for version id \(versionId) ...")
                let count = try Build.delete(on: context.application.db,
                                             versionId: versionId).wait()
                context.console.info("Deleted \(pluralizedCount(count, singular: "record"))")

            case let (.none, packageId?):
                context.console.info("Deleting builds for package id \(packageId) ...")
                let count: Int
                if let kind = signature.latest {
                    count = try Build.delete(on: context.application.db,
                                             packageId: packageId,
                                             versionKind: kind).wait()
                } else {
                    count = try Build.delete(on: context.application.db,
                                                 packageId: packageId).wait()
                }
                context.console.info("Deleted \(pluralizedCount(count, singular: "record"))")

            case (.some, .some):
                context.console.error("Specift either 'version-id' or 'package-id' but not both")

            case (.none, .none):
                context.console.error("Specify either 'version-id' or 'package-id'")
        }
    }
}


extension Version.Kind: LosslessStringConvertible {
    init?(_ description: String) {
        self.init(rawValue: description)
    }

    var description: String {
        rawValue
    }
}
