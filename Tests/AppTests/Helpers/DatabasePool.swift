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
        let index: Int
        let connectionDetails: ConnectionDetails

        init(index: Int) {
            self.index = index
            self.connectionDetails = .init(index: index)
        }

        var host: String { connectionDetails.host }
        var port: Int { connectionDetails.port }
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

        let runningDbs = try await runningDatabases()

        if isRunningInCI() {
            // In CI, running dbs are new and need to be set up
            try await withThrowingTaskGroup(of: Database.self) { group in
                for db in runningDbs {
                    group.addTask {
                        try await db.setup(for: .testing)
                        return db
                    }
                }
                for try await db in group {
                    availableDatabases.insert(db)
                }
            }
        } else {
            // Re-use up to maxCount running dbs
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

        print("ℹ️ availableDatabases:", availableDatabases.count)
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
            return (0..<Environment.databasePoolSize).map(Database.init(index:))
        } else {
            let stdout = try await ShellOut.shellOut(to: .getContainerNames).stdout
            return stdout
                .components(separatedBy: "\n")
                .filter { $0.starts(with: "spi_test_") }
                .map { String($0.dropFirst("spi_test_".count)) }
                .compactMap(Int.init)
                .map(Database.init(index:))
        }
    }

    private func retainDatabase() async throws -> Database {
        var database = availableDatabases.randomElement()
        while database == nil {
            try await Task.sleep(for: .milliseconds(10))
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
        return .init(index: port)
    }

    private func removeDB(database: Database, maxAttempts: Int = 3) async throws {
        try await run(maxAttempts: 3) { attempt in
            // print("⚠️ Removing DB on port \(database.port) (attempt: \(attempt))")
            try await ShellOut.shellOut(to: .removeDB(port: database.index))
        }
    }
}


extension DatabasePool.Database {

    struct ConnectionDetails: Hashable {
        var host: String
        var port: Int
        var username: String
        var password: String

        init(index: Int) {
            // Ensure DATABASE_HOST is from a restricted set db hostnames and nothing else.
            // This is safeguard against accidental inheritance of setup in QueryPerformanceTests
            // and to ensure the database resetting cannot impact any other network hosts.
            if isRunningInCI() {
                self.host = "spi_test_\(index)"
                self.port = 5432
            } else {
                self.host = Environment.get("DATABASE_HOST")!
                precondition(["localhost", "postgres", "host.docker.internal"].contains(host),
                             "DATABASE_HOST must be a local db, was: \(host)")
                self.port = index
            }
            self.username = Environment.get("DATABASE_USERNAME")!
            self.password = Environment.get("DATABASE_PASSWORD")!
        }
    }

    func setup(for environment: Environment) async throws {
        // Create initial db snapshot
        try await createSchema(environment)
        try await createSnapshot()
    }

    func createSchema(_ environment: Environment) async throws {
        let start = Date()
        print("ℹ️ \(#function) start")
        defer { print("ℹ️ \(#function) end", Date().timeIntervalSince(start)) }
        do {
            try await _withDatabase("postgres", details: connectionDetails, timeout: .seconds(10)) {  // Connect to `postgres` db in order to reset the test db
                let databaseName = Environment.get("DATABASE_NAME")!
                try await $0.query(PostgresQuery(unsafeSQL: "DROP DATABASE IF EXISTS \(databaseName) WITH (FORCE)"))
                try await $0.query(PostgresQuery(unsafeSQL: "CREATE DATABASE \(databaseName)"))
            }

            do {  // Use autoMigrate to spin up the schema
                let app = try await Application.make(environment)
                app.logger = .init(label: "noop") { _ in SwiftLogNoOpLogHandler() }
                try await configure(app, databaseHost: connectionDetails.host, databasePort: connectionDetails.port)
                try await app.autoMigrate()
                try await app.asyncShutdown()
            }
        } catch {
            print("Create schema failed with error: ", String(reflecting: error))
            throw error
        }
    }

    func createSnapshot() async throws {
        let start = Date()
        print("ℹ️ \(#function) start")
        defer { print("ℹ️ \(#function) end", Date().timeIntervalSince(start)) }
        let original = Environment.get("DATABASE_NAME")!
        let snapshot = original + "_snapshot"
        do {
            try await _withDatabase("postgres", details: connectionDetails, timeout: .seconds(10)) { client in
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
            try await _withDatabase("postgres", details: details, timeout: .seconds(10)) { client in
                try await client.query(PostgresQuery(unsafeSQL: "DROP DATABASE IF EXISTS \(original) WITH (FORCE)"))
                try await client.query(PostgresQuery(unsafeSQL: "CREATE DATABASE \(original) TEMPLATE \(snapshot)"))
            }
        } catch {
            print("Restore snapshot failed with error: ", String(reflecting: error))
            throw error
        }
    }

}


private func connect(to databaseName: String, details: DatabasePool.Database.ConnectionDetails) -> PostgresClient {
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
                           timeout: Duration,
                           _ query: @Sendable @escaping (PostgresClient) async throws -> Void) async throws {
    let client = connect(to: databaseName, details: details)
    try await run(timeout: timeout) {
        try await withThrowingTaskGroup { taskGroup in
            taskGroup.addTask { await client.run() }

            taskGroup.addTask { try await query(client) }

            try await taskGroup.next()
            taskGroup.cancelAll()
        }
    }
}


extension Environment {
    static var databasePoolSize: Int {
        if isRunningInCI() {
            8
        } else {
            Environment.get("DATABASEPOOL_SIZE").flatMap(Int.init) ?? 8
        }
    }

    static var databasePoolTearDown: Bool {
        if isRunningInCI() {
            false
        } else {
            Environment.get("DATABASEPOOL_TEARDOWN").flatMap(\.asBool) ?? true
        }
    }
}


#warning("remove later")
extension String: Swift.Error { }


private enum TimeoutError: Error {
    case timeout
    case noResult
}


private func run(timeout: Duration, operation: @escaping @Sendable () async throws -> Void) async throws {
    try await withThrowingTaskGroup(of: Bool.self) { group in
        group.addTask {
            try? await Task.sleep(for: timeout)
            return false
        }
        group.addTask {
            try await operation()
            return true
        }
        let res = await group.nextResult()
        group.cancelAll()
        switch res {
            case .success(false):
                throw TimeoutError.timeout
            case .success(true):
                break
            case .failure(let error):
                throw error
            case .none:
                throw TimeoutError.noResult
        }
    }
}
