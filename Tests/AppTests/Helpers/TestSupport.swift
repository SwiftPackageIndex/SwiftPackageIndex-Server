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

@testable import App

import Dependencies
import Vapor


func withApp(_ setup: (Application) async throws -> Void = { _ in },
             _ updateValuesForOperation: (inout DependencyValues) async throws -> Void = { _ in },
             logHandler: LogHandler? = nil,
             environment: Environment = .testing,
             _ test: (Application) async throws -> Void) async throws {
    try await AppTestCase.setupDb(environment)
    let app = try await AppTestCase.setupApp(environment)

    return try await run {
        try await setup(app)
        try await withDependencies(updateValuesForOperation) {
            try await withDependencies {
                $0.logger.set(to: logHandler)
            } operation: {
                try await test(app)
            }
        }
    } defer: {
        try await app.asyncShutdown()
    }
}


func isRunningInCI() -> Bool {
    ProcessInfo.processInfo.environment.keys.contains("GITHUB_WORKFLOW")
}
