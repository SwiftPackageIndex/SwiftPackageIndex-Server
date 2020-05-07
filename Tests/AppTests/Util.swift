import Fluent
import Vapor
import XCTest

@testable import App


// MARK: - Test helpers


func setup(_ environment: Environment, resetDb: Bool = true) throws -> Application {
    // Always start with a baseline mock environment to avoid hitting live resources
    Current = .mock
    
    let app = Application(.testing)
    try configure(app)
    if resetDb {
        try app.autoRevert().wait()
        try app.autoMigrate().wait()
    }
    return app
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


extension XCTestCase {
    var isRunningInCI: Bool {
        ProcessInfo.processInfo.environment.keys.contains("GITHUB_WORKFLOW")
    }
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


func fetch(id: Package.Id?, on db: Database, file: StaticString = #file, line: UInt = #line) throws -> Package {
    try XCTUnwrap(try Package.find(id, on: db).wait(), file: file, line: line)
}


// MARK: - Client mocking


class MockClient: Client {
    var response: ClientResponse

    func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        eventLoop.makeSucceededFuture(response)
    }

    var eventLoop: EventLoop {
        return EmbeddedEventLoop()
    }

    func delegating(to eventLoop: EventLoop) -> Client {
        self
    }

    init(_ updateResponse: (inout ClientResponse) -> Void) {
        self.response = ClientResponse()
        updateResponse(&self.response)
    }
}


func makeBody(_ string: String) -> ByteBuffer {
    var buffer: ByteBuffer = ByteBuffer.init(.init())
    buffer.writeString(string)
    return buffer
}


// MARK: - Useful extensions


extension URL: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        precondition(!value.isEmpty, "cannot convert empty string to URL")
        self = URL(string: value)!
    }
}


extension String {
    var url: URL { URL(string: self)! }
}


extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }
}


extension Array where Element: FluentKit.Model {
    public func save(on database: Database) -> EventLoopFuture<Void> {
        map {
            $0.save(on: database)
        }.flatten(on: database.eventLoop)
    }
}


extension String {
    var gh: String { "https://github.com/foo/\(self)" }
}


extension Array where Element == String {
    var gh: Self { map(\.gh) }
}


// MARK: - custom asserts


extension XCTestCase {
    func assertEquals<Root, Value: Equatable>(_ keyPath: KeyPath<Root, Value>,
                                              _ value1: Root,
                                              _ value2: Root,
                                              file: StaticString = #file,
                                              line: UInt = #line) {
        XCTAssertEqual(value1[keyPath: keyPath],
                       value2[keyPath: keyPath],
                       "\(value1[keyPath: keyPath]) not equal to \(value2[keyPath: keyPath])",
                       file: file, line: line)
    }

    func assertEquals<Root, Value: Equatable>(_ values: [Root],
                                              _ keyPath: KeyPath<Root, Value>,
                                              _ expectations: [Value],
                                              file: StaticString = #file,
                                              line: UInt = #line) {
        XCTAssertEqual(values.map { $0[keyPath: keyPath] },
                       expectations,
                       "\(values.map { $0[keyPath: keyPath] }) not equal to \(expectations)",
                       file: file, line: line)
    }
}
