// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Vapor


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
