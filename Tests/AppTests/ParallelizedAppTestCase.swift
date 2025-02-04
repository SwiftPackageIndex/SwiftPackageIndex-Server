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
import SQLKit
import ShellOut
import Vapor


class ParallelizedAppTestCase: XCTestCase {
    var app: Application!
    let logger = CapturingLogger()

    override func setUp() async throws {
        try await super.setUp()
        app = try await setup(.testing)

        @Dependency(\.logger) var logger
        logger.set(to: .init(label: "test", factory: { _ in self.logger }))
    }

    var dbInfo: (id: UUID, port: Int)!

    func setup(_ environment: Environment) async throws -> Application {
        try await withDependencies {
            // Setting builderToken here when it's also set in all tests may seem redundant but it's
            // what allows test_post_buildReport_large to work.
            // See https://github.com/pointfreeco/swift-dependencies/discussions/300#discussioncomment-11252906
            // for details.
            $0.environment.builderToken = { "secr3t" }
        } operation: {
            self.dbInfo = try await launchDB()

            let app = try await AppTestCase.setupApp(environment, databasePort: dbInfo.port)

            let capturingLogger = CapturingLogger()
            @Dependency(\.logger) var logger
            logger.set(to: .init(label: "test", factory: { _ in capturingLogger }))

            try await setupDB(on: dbInfo.port, app: app)

            return app
        }
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
        try await super.tearDown()
        _ = try? await ShellOut.shellOut(to: .removeDB(id: dbInfo.id))
    }

}


private func launchDB() async throws -> (id: UUID, port: Int) {
    let id = UUID()
    let port = Int.random(in: 10_000...65_000)
    _ = try? await ShellOut.shellOut(to: .removeDB(id: id))
    let maxAttempts = 3
    var attemptsLeft = maxAttempts
    while attemptsLeft > 0 {
        do {
            print("⚠️ Launching DB \(id) on port \(port)")
            try await ShellOut.shellOut(to: .launchDB(id: id, port: port))
        } catch {
            if attemptsLeft != maxAttempts {
                try? await Task.sleep(for: .milliseconds(200))
            }
            attemptsLeft -= 1
        }
    }
    return (id, port)
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


extension ParallelizedAppTestCase {
    func renderSQL(_ builder: SQLSelectBuilder) -> String {
        renderSQL(builder.query)
    }

    func renderSQL(_ query: SQLExpression) -> String {
        var serializer = SQLSerializer(database: app.db as! SQLDatabase)
        query.serialize(to: &serializer)
        return serializer.sql
    }

    func binds(_ builder: SQLSelectBuilder?) -> [String] {
        binds(builder?.query)
    }

    func binds(_ query: SQLExpression?) -> [String] {
        var serializer = SQLSerializer(database: app.db as! SQLDatabase)
        query?.serialize(to: &serializer)
        return serializer.binds.reduce(into: []) { result, bind in
            switch bind {
                case let bind as Date:
                    result.append(DateFormatter.filterParseFormatter.string(from: bind))
                case let bind as Set<Package.PlatformCompatibility>:
                    let s = bind.map(\.rawValue).sorted().joined(separator: ",")
                    result.append("{\(s)}")
                case let bind as Set<ProductTypeSearchFilter.ProductType>:
                    let s = bind.map(\.rawValue).sorted().joined(separator: ",")
                    result.append("{\(s)}")
                default:
                    result.append("\(bind)")
            }
        }
    }
}
