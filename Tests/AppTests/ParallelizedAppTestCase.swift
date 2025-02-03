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


import XCTest

@testable import App

import Dependencies
import ShellOut
import Vapor


class ParallelizedAppTestCase: XCTestCase {

    private func withApp(_ environment: Environment, _ test: (Application, CapturingLogger) async throws -> Void) async throws {
        let dbOffset = await dbIndex.withValue { index in
            index = index + 1
            return index
        }
        let port = 10_000 + dbOffset
        try await relaunchDB(on: port)

        let app = try await AppTestCase.setupApp(environment, databasePort: port)

        let capturingLogger = CapturingLogger()
        @Dependency(\.logger) var logger
        logger.set(to: .init(label: "test", factory: { _ in capturingLogger }))

        try await setupDB(on: port, app: app)

        do {
            try await test(app, capturingLogger)
        } catch {
            try await app.asyncShutdown()
            throw error
        }

        try await app.asyncShutdown()
    }

}


private let dbIndex = ActorIsolated(0)


private func relaunchDB(on port: Int) async throws {
    _ = try? await ShellOut.shellOut(to: .removeDB(port: port))
    try await ShellOut.shellOut(to: .launchDB(port: port))
}


private func setupDB(on port: Int, app: Application) async throws {
    let deadline = Date.now.addingTimeInterval(1)
    var dbIsReady = false
    while !dbIsReady && Date.now <= deadline {
        do {
            try await app.autoMigrate()
            dbIsReady = true
        } catch { }
    }
    XCTAssert(dbIsReady)
}


