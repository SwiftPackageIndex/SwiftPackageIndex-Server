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
import Fluent
import NIOConcurrencyHelpers
import PostgresNIO
import SQLKit
import XCTVapor


class AppTestCase: XCTestCase {
    var app: Application!
    let logger = CapturingLogger()

    override func setUp() async throws {
        try await super.setUp()
        app = try await setup(.testing)

        @Dependency(\.logger) var logger
        logger.set(to: self.logger)
    }

    func setup(_ environment: Environment) async throws -> Application {
        try await withDependencies {
            // Setting builderToken here when it's also set in all tests may seem redundant but it's
            // what allows test_post_buildReport_large to work.
            // See https://github.com/pointfreeco/swift-dependencies/discussions/300#discussioncomment-11252906
            // for details.
            $0.environment.builderToken = { "secr3t" }
        } operation: {
            try await Self.setupDb(environment)
            return try await Self.setupApp(environment)
        }
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
        try await super.tearDown()
    }
}


extension AppTestCase {

    static func setupApp(_ environment: Environment) async throws -> Application {
        let app = try await Application.make(environment)
        try await configure(app)

        // Silence app logging
        app.logger = .init(label: "noop") { _ in SwiftLogNoOpLogHandler() }

        return app
    }


    static func setupDb(_ environment: Environment) async throws {
        await DotEnvFile.load(for: environment, fileio: .init(threadPool: .singleton))

        // Ensure DATABASE_HOST is from a restricted set db hostnames and nothing else.
        // This is safeguard against accidental inheritance of setup in QueryPerformanceTests
        // and to ensure the database resetting cannot impact any other network hosts.
        let host = Environment.get("DATABASE_HOST")
        precondition(["localhost", "postgres", "host.docker.internal"].contains(host),
                     "DATABASE_HOST must be a local db, was: \(host)")

        let testDbName = Environment.get("DATABASE_NAME")!
        let snapshotName = testDbName + "_snapshot"

        // Create initial db snapshot on first run
        try await snapshotCreated.withValue { snapshotCreated in
            if !snapshotCreated {
                try await createSchema(environment, databaseName: testDbName)
                try await createSnapshot(original: testDbName, snapshot: snapshotName, environment: environment)
                snapshotCreated = true
            }
        }

        try await restoreSnapshot(original: testDbName, snapshot: snapshotName, environment: environment)
    }


    static func createSchema(_ environment: Environment, databaseName: String) async throws {
        do {
            try await withDatabase("postgres", environment) {  // Connect to `postgres` db in order to reset the test db
                try await $0.query(PostgresQuery(unsafeSQL: "DROP DATABASE IF EXISTS \(databaseName) WITH (FORCE)"))
                try await $0.query(PostgresQuery(unsafeSQL: "CREATE DATABASE \(databaseName)"))
            }

            do {  // Use autoMigrate to spin up the schema
                let app = try await Application.make(environment)
                app.logger = .init(label: "noop") { _ in SwiftLogNoOpLogHandler() }
                try await configure(app)
                try await app.autoMigrate()
                try await app.asyncShutdown()
            }
        } catch {
            print("Create schema failed with error: ", String(reflecting: error))
            throw error
        }
    }


    static func createSnapshot(original: String, snapshot: String, environment: Environment) async throws {
        do {
            try await withDatabase("postgres", environment) { client in
                try await client.query(PostgresQuery(unsafeSQL: "DROP DATABASE IF EXISTS \(snapshot) WITH (FORCE)"))
                try await client.query(PostgresQuery(unsafeSQL: "CREATE DATABASE \(snapshot) TEMPLATE \(original)"))
            }
        } catch {
            print("Create snapshot failed with error: ", String(reflecting: error))
            throw error
        }
    }


    static func restoreSnapshot(original: String, snapshot: String, environment: Environment) async throws {
        // delete db and re-create from snapshot
        do {
            try await withDatabase("postgres", environment) { client in
                try await client.query(PostgresQuery(unsafeSQL: "DROP DATABASE IF EXISTS \(original) WITH (FORCE)"))
                try await client.query(PostgresQuery(unsafeSQL: "CREATE DATABASE \(original) TEMPLATE \(snapshot)"))
            }
        } catch {
            print("Restore snapshot failed with error: ", String(reflecting: error))
            throw error
        }
    }


    static let snapshotCreated = ActorIsolated(false)

}


extension AppTestCase {
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


// FIXME: Move this once AppTestCase can be removed. These are helpers created during the transition to Swift Testing.
extension Database {
    func renderSQL(_ query: SQLExpression) -> String {
        var serializer = SQLSerializer(database: self as! SQLDatabase)
        query.serialize(to: &serializer)
        return serializer.sql
    }

    func binds(_ query: SQLExpression?) -> [String] {
        var serializer = SQLSerializer(database: self as! SQLDatabase)
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


private func connect(to databaseName: String, _ environment: Environment) async throws -> PostgresClient {
    await DotEnvFile.load(for: environment, fileio: .init(threadPool: .singleton))
    let host = Environment.get("DATABASE_HOST")!
    let port = Environment.get("DATABASE_PORT").flatMap(Int.init)!
    let username = Environment.get("DATABASE_USERNAME")!
    let password = Environment.get("DATABASE_PASSWORD")!

    let config = PostgresClient.Configuration(host: host, port: port, username: username, password: password, database: databaseName, tls: .disable)

    return .init(configuration: config)
}


private func withDatabase(_ databaseName: String, _ environment: Environment, _ query: @escaping (PostgresClient) async throws -> Void) async throws {
    let client = try await connect(to: databaseName, environment)
    try await withThrowingTaskGroup(of: Void.self) { taskGroup in
        taskGroup.addTask { await client.run() }

        try await query(client)

        taskGroup.cancelAll()
    }
}

