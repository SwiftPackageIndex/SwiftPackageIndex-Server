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
    let app = try await Application.make(environment)
    let host = try await configure(app)

    // Ensure `.testing` refers to "postgres" or "localhost"
    precondition(["localhost", "postgres", "host.docker.internal"].contains(host),
                 ".testing must be a local db, was: \(host)")

    app.logger.logLevel = Environment.get("LOG_LEVEL").flatMap(Logger.Level.init(rawValue:)) ?? .warning

    if !(_schemaCreated.withLockedValue { $0 }) {
        // ensure we create the schema when running the first test
        try await app.autoMigrate()
        _schemaCreated.withLockedValue { $0 = true }
    }
    if resetDb { try await _resetDb(app) }

    // Always start with a baseline mock environment to avoid hitting live resources
    Current = .mock(eventLoop: app.eventLoopGroup.next())

    return app
}


private let tableNamesCache: NIOLockedValueBox<[String]?> = .init(nil)

func _resetDb(_ app: Application) async throws {
    guard let db = app.db as? SQLDatabase else {
        fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
    }

    guard let tables = tableNamesCache.withLockedValue({ $0 }) else {
        struct Row: Decodable { var table_name: String }
        let tableNames = try await db.raw("""
                SELECT table_name FROM
                information_schema.tables
                WHERE
                  table_schema NOT IN ('pg_catalog', 'information_schema', 'public._fluent_migrations')
                  AND table_schema NOT LIKE 'pg_toast%'
                  AND table_name NOT LIKE '_fluent_%'
                """)
            .all(decoding: Row.self)
            .map(\.table_name)
        tableNamesCache.withLockedValue { $0 = tableNames }
        try await _resetDb(app)
        return
    }

    for table in tables {
        try await db.raw("TRUNCATE TABLE \(ident: table) CASCADE").run()
    }

    try await RecentPackage.refresh(on: app.db)
    try await RecentRelease.refresh(on: app.db)
    try await Search.refresh(on: app.db).get()
    try await Stats.refresh(on: app.db).get()
    try await WeightedKeyword.refresh(on: app.db).get()
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


// TODO: deprecate in favour of savePackage[Async](...) async throws
@discardableResult
func savePackage(on db: Database, id: Package.Id = UUID(), _ url: URL,
                 processingStage: Package.ProcessingStage? = nil) throws -> Package {
    let p = Package(id: id, url: url, processingStage: processingStage)
    try p.save(on: db).wait()
    return p
}


// TODO: deprecate in favour of savePackages[Async](...) async throws
@discardableResult
func savePackages(on db: Database, _ urls: [URL],
                  processingStage: Package.ProcessingStage? = nil) throws -> [Package] {
    try urls.map { try savePackage(on: db, $0, processingStage: processingStage) }
}


@discardableResult
func savePackageAsync(on db: Database, id: Package.Id = UUID(), _ url: URL,
                      processingStage: Package.ProcessingStage? = nil) async throws -> Package {
    let p = Package(id: id, url: url, processingStage: processingStage)
    try await p.save(on: db)
    return p
}


@discardableResult
func savePackagesAsync(on db: Database, _ urls: [URL],
                       processingStage: Package.ProcessingStage? = nil) async throws -> [Package] {
    try await urls.mapAsync {
        try await savePackageAsync(on: db, $0, processingStage: processingStage)
    }
}


func fetch(id: Package.Id?, on db: Database, file: StaticString = #file, line: UInt = #line) throws -> Package {
    try XCTUnwrap(try Package.find(id, on: db).wait(), file: (file), line: line)
}


// MARK: - Client mocking


class MockClient: Client, @unchecked Sendable {
    let eventLoopGroup: EventLoopGroup
    var updateResponse: (ClientRequest, inout ClientResponse) -> Void

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
