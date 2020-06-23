@testable import App

import Fluent
import SQLKit
import Vapor
import XCTest


// MARK: - Test helpers

private var _schemaCreated = false

func setup(_ environment: Environment, resetDb: Bool = true) throws -> Application {
    // Always start with a baseline mock environment to avoid hitting live resources
    Current = .mock
    
    let app = Application(.testing)
    app.logger.logLevel = Environment.get("LOG_LEVEL").flatMap(Logger.Level.init(rawValue:)) ?? .warning
    try configure(app)
    if !_schemaCreated {
        // ensure we create the schema when running the first test
        try app.autoMigrate().wait()
        _schemaCreated = true
    }
    if resetDb { try _resetDb(app) }
    return app
}


private var _tables: [String]?

func _resetDb(_ app: Application) throws {
    guard let db = app.db as? SQLDatabase else {
        fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
    }

    guard let tables = _tables else {
        struct Row: Decodable { var table_name: String }
        _tables = try db.raw("""
                SELECT table_name FROM
                information_schema.tables
                WHERE
                  table_schema NOT IN ('pg_catalog', 'information_schema', 'public._fluent_migrations')
                  AND table_schema NOT LIKE 'pg_toast%'
                  AND table_name NOT LIKE '_fluent_%'
                """)
            .all(decoding: Row.self)
            .wait()
            .map(\.table_name)
        if _tables != nil { try _resetDb(app) }
        return
    }

    for table in tables {
        try db.raw("TRUNCATE TABLE \(table) CASCADE").run().wait()
    }
}


func loadData(for fixture: String) throws -> Data {
    let url = fixturesDirectory().appendingPathComponent(fixture)
    return try Data(contentsOf: url)
}


func fixturesDirectory(path: String = #file) -> URL {
    let url = URL(fileURLWithPath: path)
    let testsDir = url.deletingLastPathComponent()
    let res = testsDir.appendingPathComponent("Fixtures")
    return res
}


// MARK: - Package db helpers


@discardableResult
func savePackage(on db: Database, _ url: URL, processingStage: ProcessingStage? = nil) throws -> Package {
    let p = Package(id: UUID(), url: url, processingStage: processingStage)
    try p.save(on: db).wait()
    return p
}


@discardableResult
func savePackages(on db: Database, _ urls: [URL], processingStage: ProcessingStage? = nil) throws -> [Package] {
    try urls.map { try savePackage(on: db, $0, processingStage: processingStage) }
}


func fetch(id: Package.Id?, on db: Database, file: StaticString = #filePath, line: UInt = #line) throws -> Package {
    try XCTUnwrap(try Package.find(id, on: db).wait(), file: file, line: line)
}


// MARK: - Client mocking


class MockClient: Client {
    var updateResponse: (ClientRequest, inout ClientResponse) -> Void

    func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        var response = ClientResponse()
        updateResponse(request, &response)
        return eventLoop.makeSucceededFuture(response)
    }

    var eventLoop: EventLoop {
        return EmbeddedEventLoop()
    }

    func delegating(to eventLoop: EventLoop) -> Client {
        self
    }

    init(_ updateResponse: @escaping (ClientRequest, inout ClientResponse) -> Void) {
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
