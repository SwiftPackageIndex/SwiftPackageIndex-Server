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

import AsyncHTTPClient
import S3Store
import SPIManifest
import ShellOut
import Vapor
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif


struct AppEnvironment: Sendable {
    var git: Git
    var logger: @Sendable () -> Logger
    var setLogger: @Sendable (Logger) -> Void
    var shell: Shell
}


extension AppEnvironment {
    nonisolated(unsafe) static var logger: Logger!

    static let live = AppEnvironment(
        git: .live,
        logger: { logger },
        setLogger: { logger in Self.logger = logger },
        shell: .live
    )
}



struct Git: Sendable {
    var shortlog: @Sendable (String) async throws -> String

    static let live: Self = .init(
        shortlog: { path in try await shortlog(at: path) }
    )
}


struct Shell: Sendable {
    var run: @Sendable (ShellOutCommand, String) async throws -> String

    // also provide pass-through methods to preserve argument labels
    @discardableResult
    func run(command: ShellOutCommand, at path: String = ".") async throws -> String {
        do {
            return try await run(command, path)
        } catch {
            // re-package error to capture more information
            throw AppError.shellCommandFailed(command.description, path, error.localizedDescription)
        }
    }

    static let live: Self = .init(
        run: {
            let res = try await ShellOut.shellOut(to: $0, at: $1, logger: Current.logger())
            if !res.stderr.isEmpty {
                Current.logger().warning("stderr: \(res.stderr)")
            }
            return res.stdout
        }
    )
}


#if DEBUG
nonisolated(unsafe) var Current: AppEnvironment = .live
#else
let Current: AppEnvironment = .live
#endif
