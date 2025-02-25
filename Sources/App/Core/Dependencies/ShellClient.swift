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

import Dependencies
import DependenciesMacros
import ShellOut


@DependencyClient
struct ShellClient {
    var run: @Sendable (ShellOutCommand, String) async throws -> String
}


extension ShellClient {
    @discardableResult
    func run(command: ShellOutCommand, at path: String) async throws -> String {
        try await run(command, path)
    }
}


extension String {
    static let cwd = "."
}


extension ShellClient: DependencyKey {
    static var liveValue: Self {
        .init(
            run: { command, path in
                @Dependency(\.logger) var logger
                do {
                    let res = try await ShellOut.shellOut(to: command, at: path, logger: logger)
                    if !res.stderr.isEmpty {
                        logger.warning("stderr: \(res.stderr)")
                    }
                    return res.stdout
                } catch {
                    // re-package error to capture more information
                    throw AppError.shellCommandFailed(command.description, path, error.localizedDescription)
                }
            }
        )
    }
}


extension ShellClient: TestDependencyKey {
    static var testValue: Self { .init() }
}


extension DependencyValues {
    var shell: ShellClient {
        get { self[ShellClient.self] }
        set { self[ShellClient.self] = newValue }
    }
}
