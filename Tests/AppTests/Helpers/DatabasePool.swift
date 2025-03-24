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

import PostgresNIO
import ShellOut
import Vapor



actor DatabasePool {
    struct Database: Hashable {
        var port: Int

        var connectionDetails: ConnectionDetails {
            .init(port: port)
        }
    }

    static let shared = DatabasePool(maxCount: Environment.databasePoolSize)

    var maxCount: Int

    init(maxCount: Int) {
        self.maxCount = maxCount
    }

    var availableDatabases: Set<Database> = .init()

    func setUp() async throws {
        // Call DotEnvFile.load once to ensure env variables are set
        await DotEnvFile.load(for: .testing, fileio: .init(threadPool: .singleton))

        // Re-use up to maxCount running dbs
        let runningDbs = try await runningDatabases()
        for db in runningDbs.prefix(maxCount) {
            availableDatabases.insert(db)
        }

        do { // Delete overprovisioned dbs
            let overprovisioned = runningDbs.dropFirst(maxCount)
            try await tearDown(databases: overprovisioned)
        }

        do { // Create missing dbs
            let underprovisionedCount = max(maxCount - availableDatabases.count, 0)
            try await withThrowingTaskGroup(of: Database.self) { group in
                for _ in (0..<underprovisionedCount) {
                    group.addTask {
                        let db = try await self.launchDB()
                        try await db.setup(for: .testing)
                        return db
                    }
                }
                for try await db in group {
                    availableDatabases.insert(db)
                }
            }
        }
    }

    func tearDown() async throws {
        try await tearDown(databases: runningDatabases())
    }

    func tearDown(databases: any Collection<Database>) async throws {
        guard Environment.databasePoolTearDown else { return }
        try await withThrowingTaskGroup { group in
            for db in databases {
                group.addTask {
                    try await self.removeDB(database: db)
                }
            }
            try await group.waitForAll()
        }
    }

    func withDatabase(_ operation: @Sendable (Database) async throws -> Void) async throws {
        let db = try await retainDatabase()
        do {
            try await operation(db)
            try await releaseDatabase(database: db)
        } catch {
            try await releaseDatabase(database: db)
            throw error
        }
    }

    private func runningDatabases() async throws -> [Database] {
        if isRunningInCI() {
            // We don't have docker available in CI to probe for running dbs.
            // Instead, we have a hard-coded list of dbs we launch in the GH workflow
            // file and correspondingly, we hard-code their ports here.
            return (6000..<6008).map(Database.init)
        } else {
            let stdout = try await ShellOut.shellOut(to: .getContainerNames).stdout
            return stdout
                .components(separatedBy: "\n")
                .filter { $0.starts(with: "spi_test_") }
                .map { String($0.dropFirst("spi_test_".count)) }
                .compactMap(Int.init)
                .map(Database.init(port:))
        }
    }

    private func retainDatabase() async throws -> Database {
        var database = availableDatabases.randomElement()
        while database == nil {
            try await Task.sleep(for: .milliseconds(100))
            database = availableDatabases.randomElement()
        }
        guard let database else { fatalError("database cannot be nil here") }
        availableDatabases.remove(database)
        return database
    }

    private func releaseDatabase(database: Database) async throws {
        availableDatabases.insert(database)
    }

    private func launchDB(maxAttempts: Int = 3) async throws -> Database {
        let port = Int.random(in: 10_000...65_000)
        _ = try? await ShellOut.shellOut(to: .removeDB(port: port))
        try await run(maxAttempts: 3) { attempt in
            print("⚠️ Launching DB on port \(port) (attempt: \(attempt))")
            try await ShellOut.shellOut(to: .launchDB(port: port))
        }
        return .init(port: port)
    }

    private func removeDB(database: Database, maxAttempts: Int = 3) async throws {
        try await run(maxAttempts: 3) { attempt in
            // print("⚠️ Removing DB on port \(database.port) (attempt: \(attempt))")
            try await ShellOut.shellOut(to: .removeDB(port: database.port))
        }
    }
}


extension DatabasePool.Database {

    struct ConnectionDetails {
        var host: String
        var port: Int
        var username: String
        var password: String

        init(port: Int) {
            // Ensure DATABASE_HOST is from a restricted set db hostnames and nothing else.
            // This is safeguard against accidental inheritance of setup in QueryPerformanceTests
            // and to ensure the database resetting cannot impact any other network hosts.
            self.host = Environment.get("DATABASE_HOST")!
            precondition(["localhost", "postgres", "host.docker.internal"].contains(host),
                         "DATABASE_HOST must be a local db, was: \(host)")
            self.port = port
            self.username = Environment.get("DATABASE_USERNAME")!
            self.password = Environment.get("DATABASE_PASSWORD")!
        }
    }

    func setup(for environment: Environment) async throws {
        let details = ConnectionDetails(port: port)

        // Create initial db snapshot
        try await createSchema(environment, details: details)
        try await createSnapshot(details: details)
    }

    func createSchema(_ environment: Environment, details: ConnectionDetails) async throws {
        do {
            try await _withDatabase("postgres", details: details) {  // Connect to `postgres` db in order to reset the test db
                let databaseName = Environment.get("DATABASE_NAME")!
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

    func createSnapshot(details: ConnectionDetails) async throws {
        let original = Environment.get("DATABASE_NAME")!
        let snapshot = original + "_snapshot"
        do {
            try await _withDatabase("postgres", details: details) { client in
                try await client.query(PostgresQuery(unsafeSQL: "DROP DATABASE IF EXISTS \(snapshot) WITH (FORCE)"))
                try await client.query(PostgresQuery(unsafeSQL: "CREATE DATABASE \(snapshot) TEMPLATE \(original)"))
            }
        } catch {
            print("Create snapshot failed with error: ", String(reflecting: error))
            throw error
        }
    }

    func restoreSnapshot(details: ConnectionDetails) async throws {
        let original = Environment.get("DATABASE_NAME")!
        let snapshot = original + "_snapshot"
        // delete db and re-create from snapshot
        do {
            try await _withDatabase("postgres", details: details) { client in
                try await client.query(PostgresQuery(unsafeSQL: "DROP DATABASE IF EXISTS \(original) WITH (FORCE)"))
                try await client.query(PostgresQuery(unsafeSQL: "CREATE DATABASE \(original) TEMPLATE \(snapshot)"))
            }
        } catch {
            print("Restore snapshot failed with error: ", String(reflecting: error))
            throw error
        }
    }

}


private func connect(to databaseName: String, details: DatabasePool.Database.ConnectionDetails) async throws -> PostgresClient {
    let config = PostgresClient.Configuration(
        host: details.host,
        port: details.port,
        username: details.username,
        password: details.password,
        database: databaseName,
        tls: .disable
    )

    return .init(configuration: config)
}


private func _withDatabase(_ databaseName: String,
                           details: DatabasePool.Database.ConnectionDetails,
                           _ query: @escaping (PostgresClient) async throws -> Void) async throws {
    let client = try await connect(to: databaseName, details: details)
    try await withThrowingTaskGroup(of: Void.self) { taskGroup in
        taskGroup.addTask { await client.run() }

        try await query(client)

        taskGroup.cancelAll()
    }
}


extension Environment {
    static var databasePoolSize: Int {
        Environment.get("DATABASEPOOL_SIZE").flatMap(Int.init) ?? 4
    }

    static var databasePoolTearDown: Bool {
        Environment.get("DATABASEPOOL_TEARDOWN").flatMap(\.asBool) ?? true
    }
}
