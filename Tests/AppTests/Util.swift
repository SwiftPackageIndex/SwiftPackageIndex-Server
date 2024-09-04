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

import Fluent
import SQLKit
import Vapor
import XCTest
import NIOConcurrencyHelpers


// MARK: - Test helpers

private let _schemaCreated = NIOLockedValueBox<Bool>(false)

func setup(_ environment: Environment, resetDb: Bool = true) async throws -> Application {
    if !(_schemaCreated.withLockedValue { $0 }) {
        print("Creating initial schema...")
        await DotEnvFile.load(for: environment, fileio: .init(threadPool: .singleton))
        let testDb = Environment.get("DATABASE_NAME")!
        do {
            try await withDatabase("postgres") {
                try await $0.query(PostgresQuery(unsafeSQL: "DROP DATABASE IF EXISTS \(testDb) WITH (FORCE)"))
                try await $0.query(PostgresQuery(unsafeSQL: "CREATE DATABASE \(testDb)"))
            }
        } catch {
            print(String(reflecting: error))
            throw error
        }
        do {  // ensure we re-create the schema when running the first test
            let app = try await Application.make(environment)
            try await configure(app)
            try await app.autoMigrate()
            _schemaCreated.withLockedValue { $0 = true }
            try await app.asyncShutdown()
        } catch {
            print(String(reflecting: error))
            throw error
        }
        print("Created initial schema.")
    }

    if resetDb {
        let start = Date()
        defer { print("Resetting database took: \(Date().timeIntervalSince(start))s") }
        try await _resetDb()
//        try await RecentPackage.refresh(on: app.db)
//        try await RecentRelease.refresh(on: app.db)
//        try await Search.refresh(on: app.db)
//        try await Stats.refresh(on: app.db)
//        try await WeightedKeyword.refresh(on: app.db)
    }

    let app = try await Application.make(environment)
    let host = try await configure(app)

    // Ensure `.testing` refers to "postgres" or "localhost"
    precondition(["localhost", "postgres", "host.docker.internal"].contains(host),
                 ".testing must be a local db, was: \(host)")


    app.logger.logLevel = Environment.get("LOG_LEVEL").flatMap(Logger.Level.init(rawValue:)) ?? .warning

    // Always start with a baseline mock environment to avoid hitting live resources
    Current = .mock(eventLoop: app.eventLoopGroup.next())

    return app
}


import PostgresNIO

func connect(to databaseName: String) throws -> PostgresClient {
    let host = Environment.get("DATABASE_HOST")!
    let port = Environment.get("DATABASE_PORT").flatMap(Int.init)!
    let username = Environment.get("DATABASE_USERNAME")!
    let password = Environment.get("DATABASE_PASSWORD")!

    let config = PostgresClient.Configuration(host: host, port: port, username: username, password: password, database: databaseName, tls: .disable)
    return .init(configuration: config)
}

func withDatabase(_ databaseName: String, _ query: @escaping (PostgresClient) async throws -> Void) async throws {
    let client = try connect(to: databaseName)
    try await withThrowingTaskGroup(of: Void.self) { taskGroup in
        taskGroup.addTask {
            await client.run()
        }

        try await query(client)

        taskGroup.cancelAll()
    }
}


private let tableNamesCache: NIOLockedValueBox<[String]?> = .init(nil)
private let snapshotCreated = ActorIsolated(false)

func _resetDb() async throws {
    // FIXME: get this dynamically
    let dbName = "spi_test"
    let templateName = dbName + "_template"

    try await snapshotCreated.withValue { snapshotCreated in
        if snapshotCreated {
            // delete db and re-create from snapshot
            print("Deleting and re-creating from snapshot...")
            do {
                try await withDatabase("postgres") { client in
                    try await client.query(PostgresQuery(unsafeSQL: "DROP DATABASE IF EXISTS \(dbName) WITH (FORCE)"))
                    try await client.query(PostgresQuery(unsafeSQL: "CREATE DATABASE \(dbName) TEMPLATE \(templateName)"))
                }
            } catch {
                print(String(reflecting: error))
                throw error
            }
            print("Database reset.")
        } else {
            // create snapshot
            print("Creating snapshot...")
            do {
                try await withDatabase("postgres") { client in
                    try await client.query(PostgresQuery(unsafeSQL: "DROP DATABASE IF EXISTS \(templateName) WITH (FORCE)"))
                    try await client.query(PostgresQuery(unsafeSQL: "CREATE DATABASE \(templateName) TEMPLATE \(dbName)"))
                }
            } catch {
                print(String(reflecting: error))
                throw error
            }
            snapshotCreated = true
            print("Snapshot created.")
        }
    }
}


func fixtureString(for fixture: String) throws -> String {
    String(decoding: try fixtureData(for: fixture), as: UTF8.self)
}


func fixtureData(for fixture: String) throws -> Data {
    try Data(contentsOf: fixtureUrl(for: fixture))
}


func fixtureUrl(for fixture: String) -> URL {
    fixturesDirectory().appendingPathComponent(fixture)
}


func fixturesDirectory(path: String = #file) -> URL {
    let url = URL(fileURLWithPath: path)
    let testsDir = url.deletingLastPathComponent()
    return testsDir.appendingPathComponent("Fixtures")
}


// MARK: - Package db helpers


@discardableResult
func savePackage(on db: Database, id: Package.Id = UUID(), _ url: URL,
                 processingStage: Package.ProcessingStage? = nil) async throws -> Package {
    let p = Package(id: id, url: url, processingStage: processingStage)
    try await p.save(on: db)
    return p
}


@discardableResult
func savePackages(on db: Database, _ urls: [URL],
                  processingStage: Package.ProcessingStage? = nil) async throws -> [Package] {
    try await urls.mapAsync {
        try await savePackage(on: db, $0, processingStage: processingStage)
    }
}


// MARK: - Client mocking


class MockClient: Client, @unchecked Sendable {
    let eventLoopGroup: EventLoopGroup
    var updateResponse: (ClientRequest, inout ClientResponse) -> Void

    // We have to keep this EventLoopFuture for now, because the signature is part of Vapor's Client protocol
    func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        var response = ClientResponse()
        updateResponse(request, &response)
        return eventLoop.makeSucceededFuture(response)
    }

    var eventLoop: EventLoop {
        eventLoopGroup.next()
    }

    func delegating(to eventLoop: EventLoop) -> Client {
        self
    }

    init(_ updateResponse: @escaping (ClientRequest, inout ClientResponse) -> Void) {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.updateResponse = updateResponse
    }
}


func makeBody(_ string: String) -> ByteBuffer {
    var buffer: ByteBuffer = ByteBuffer.init(.init())
    buffer.writeString(string)
    return buffer
}


func makeBody(_ data: Data) -> ByteBuffer {
    var buffer: ByteBuffer = ByteBuffer.init(.init())
    buffer.writeBytes(data)
    return buffer
}
