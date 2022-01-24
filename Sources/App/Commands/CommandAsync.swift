import Vapor


protocol CommandAsync: Command {
    // Specifically avoid marking this function `throws` to ensure all
    // errors are handled. Otherwise errors thrown would escape and
    // leave the task dangling.
    // See https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/pull/1493
    func run(using context: CommandContext, signature: Signature) async
}


extension CommandAsync {
    func run(using context: CommandContext, signature: Signature) throws {
        let group = DispatchGroup()
        group.enter()

        Task {
            defer { group.leave() }
            await run(using: context, signature: signature)
        }

        group.wait()
    }
}
