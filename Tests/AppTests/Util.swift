// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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


// MARK: - Test helpers


//private var _schemaCreated = false

//@available(*, deprecated)
//func setup(_ environment: Environment, resetDb: Bool = true) async throws -> Application {
//    try await testSchema.setup(environment, resetDb: resetDb)
//    return await testSchema.app
//}


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


class MockClient: Client {
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
