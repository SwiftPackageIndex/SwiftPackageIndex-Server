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

import Foundation

import App
import ShellOut


actor DatabasePool {
    typealias DatabaseID = UUID

    #warning("rename to Database")
    struct DatabaseInfo: Hashable {
        var id: DatabaseID
        var port: Int
    }

    static let shared = DatabasePool(maxCount: 8)

    var maxCount: Int

    init(maxCount: Int) {
        self.maxCount = maxCount
    }

    var availableDatabases: Set<DatabaseInfo> = .init()

    func setUp() async throws {
        try await withThrowingTaskGroup(of: DatabaseInfo.self) { group in
            for _ in (0..<maxCount) {
                group.addTask {
                    try await self.launchDB()
                }
            }
            for try await info in group {
                availableDatabases.insert(info)
            }
        }
    }

    func tearDown() async throws {
        try await withThrowingTaskGroup { group in
            for dbInfo in availableDatabases {
                group.addTask {
                    try await self.removeDB(dbInfo: dbInfo)
                }
            }
            try await group.waitForAll()
        }
    }

    func withDatabase(_ operation: @Sendable (DatabaseInfo) async throws -> Void) async throws {
        let dbID = try await retainDatabase()
        do {
            // print("⚠️ available", availableDatabases.map(\.port).sorted())
            try await operation(dbID)
            try await releaseDatabase(dbInfo: dbID)
        } catch {
            try await releaseDatabase(dbInfo: dbID)
            throw error
        }
    }

    private func retainDatabase() async throws -> DatabaseInfo {
        var dbInfo = availableDatabases.randomElement()
        while dbInfo == nil {
            try await Task.sleep(for: .milliseconds(100))
            dbInfo = availableDatabases.randomElement()
        }
        guard let dbInfo else { fatalError("dbInfo cannot be nil here") }
        availableDatabases.remove(dbInfo)
        return dbInfo
    }

    private func releaseDatabase(dbInfo: DatabaseInfo) async throws {
        availableDatabases.insert(dbInfo)
    }

    private func launchDB(maxAttempts: Int = 3) async throws -> DatabaseInfo {
        let id = UUID()
        let port = Int.random(in: 10_000...65_000)
        _ = try? await ShellOut.shellOut(to: .removeDB(id: id))
        try await run(maxAttempts: 3) { attempt in
            print("⚠️ Launching DB \(id) on port \(port) (attempt: \(attempt))")
            try await ShellOut.shellOut(to: .launchDB(id: id, port: port))
        }
        return .init(id: id, port: port)
    }

    private func removeDB(dbInfo: DatabaseInfo, maxAttempts: Int = 3) async throws {
        try await run(maxAttempts: 3) { attempt in
            // print("⚠️ Removing DB \(dbInfo.id) on port \(dbInfo.port) (attempt: \(attempt))")
            try await ShellOut.shellOut(to: .removeDB(id: dbInfo.id))
        }
    }
}


import PostgresNIO
import Vapor

extension DatabasePool.DatabaseInfo {

    func setupDb(_ environment: Environment) async throws {
        await DotEnvFile.load(for: environment, fileio: .init(threadPool: .singleton))

        // Ensure DATABASE_HOST is from a restricted set db hostnames and nothing else.
        // This is safeguard against accidental inheritance of setup in QueryPerformanceTests
        // and to ensure the database resetting cannot impact any other network hosts.
        let host = Environment.get("DATABASE_HOST")!
        precondition(["localhost", "postgres", "host.docker.internal"].contains(host),
                     "DATABASE_HOST must be a local db, was: \(host)")

        let testDbName = Environment.get("DATABASE_NAME")!
        let snapshotName = testDbName + "_snapshot"

        // Create initial db snapshot
        try await createSchema(environment, databaseName: testDbName)
        try await createSnapshot(original: testDbName, snapshot: snapshotName, environment: environment)

        try await restoreSnapshot(original: testDbName, snapshot: snapshotName, environment: environment)
    }

    func createSchema(_ environment: Environment, databaseName: String) async throws {
        do {
            try await _withDatabase("postgres", port: port, environment) {  // Connect to `postgres` db in order to reset the test db
                try await $0.query(PostgresQuery(unsafeSQL: "DROP DATABASE IF EXISTS \(databaseName) WITH (FORCE)"))
                try await $0.query(PostgresQuery(unsafeSQL: "CREATE DATABASE \(databaseName)"))
            }

            do {  // Use autoMigrate to spin up the schema
                let app = try await Application.make(environment)
                app.logger = .init(label: "noop") { _ in SwiftLogNoOpLogHandler() }
                try await configure(app, databasePort: port)
                try await app.autoMigrate()
                try await app.asyncShutdown()
            }
        } catch {
            print("Create schema failed with error: ", String(reflecting: error))
            throw error
        }
    }

    func createSnapshot(original: String, snapshot: String, environment: Environment) async throws {
        do {
            try await _withDatabase("postgres", port: port, environment) { client in
                try await client.query(PostgresQuery(unsafeSQL: "DROP DATABASE IF EXISTS \(snapshot) WITH (FORCE)"))
                try await client.query(PostgresQuery(unsafeSQL: "CREATE DATABASE \(snapshot) TEMPLATE \(original)"))
            }
        } catch {
            print("Create snapshot failed with error: ", String(reflecting: error))
            throw error
        }
    }

    func restoreSnapshot(original: String,
                         snapshot: String,
                         environment: Environment) async throws {
        // delete db and re-create from snapshot
        do {
            try await _withDatabase("postgres", port: port, environment) { client in
                try await client.query(PostgresQuery(unsafeSQL: "DROP DATABASE IF EXISTS \(original) WITH (FORCE)"))
                try await client.query(PostgresQuery(unsafeSQL: "CREATE DATABASE \(original) TEMPLATE \(snapshot)"))
            }
        } catch {
            print("Restore snapshot failed with error: ", String(reflecting: error))
            throw error
        }
    }

}


private func connect(to databaseName: String,
                     port: Int,
                     _ environment: Environment) async throws -> PostgresClient {
    #warning("don't load dot file, just pass in host, port, username, password tuple - or make this a method and the other values properties")
    await DotEnvFile.load(for: environment, fileio: .init(threadPool: .singleton))
    let host = Environment.get("DATABASE_HOST")!
    let username = Environment.get("DATABASE_USERNAME")!
    let password = Environment.get("DATABASE_PASSWORD")!

    let config = PostgresClient.Configuration(host: host, port: port, username: username, password: password, database: databaseName, tls: .disable)

    return .init(configuration: config)
}


private func _withDatabase(_ databaseName: String,
                           port: Int,
                           _ environment: Environment,
                           _ query: @escaping (PostgresClient) async throws -> Void) async throws {
    let client = try await connect(to: databaseName, port: port, environment)
    try await withThrowingTaskGroup(of: Void.self) { taskGroup in
        taskGroup.addTask { await client.run() }

        try await query(client)

        taskGroup.cancelAll()
    }
}

