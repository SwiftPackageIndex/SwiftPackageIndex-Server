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
import PostgresNIO


func withSPIApp(
    environment: Environment = .testing,
    _ setup: @Sendable (Application) async throws -> Void = { _ in },
    _ updateValuesForOperation: @Sendable (inout DependencyValues) async throws -> Void = { _ in },
    _ test: @Sendable (Application) async throws -> Void
) async throws {
    prepareDependencies {
        $0.logger = .noop
    }

    try await DatabasePool.shared.withDatabase { database in
        try await database.restoreSnapshot(details: database.connectionDetails)
        let app = try await Application.make(environment)
        try await configure(app, databaseHost: database.host, databasePort: database.port)

        return try await run {
            try await setup(app)
            try await withDependencies(updateValuesForOperation) {
                try await test(app)
            }
        } defer: {
            try await app.asyncShutdown()
        }
    }
}


func isRunningInCI() -> Bool {
    ProcessInfo.processInfo.environment.keys.contains("GITHUB_WORKFLOW")
}


func isRunningInDevContainer() -> Bool {
    ProcessInfo.processInfo.environment.keys.contains("RUNNING_IN_DEVCONTAINER")
}


func isDockerAvailable() -> Bool {
    if isRunningInCI() || isRunningInDevContainer() {
        false
    } else {
        true
    }
}
