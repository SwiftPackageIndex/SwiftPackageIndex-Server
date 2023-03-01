import Vapor


@available(*, deprecated)
protocol CommandAsync: Command {
    // Specifically avoid marking this function `throws` to ensure all
    // errors are handled. Otherwise errors thrown would escape and
    // leave the task dangling.
    // See https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/pull/1493
    func run(using context: CommandContext, signature: Signature) async
}


extension CommandAsync {
    @available(*, deprecated)
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


// Credit: https://theswiftdev.com/running-and-testing-async-vapor-commands/

public protocol AsyncCommand: Command {
    func run(using context: CommandContext, signature: Signature) async throws
}

public extension AsyncCommand {
    func run(using context: CommandContext, signature: Signature) throws {
        let promise = context
            .application
            .eventLoopGroup
            .next()
            .makePromise(of: Void.self)

        promise.completeWithTask {
            try await run(using: context, signature: signature)
        }
        try promise.futureResult.wait()
    }
}
