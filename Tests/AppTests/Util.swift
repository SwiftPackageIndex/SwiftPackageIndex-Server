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
import NIOConcurrencyHelpers


// MARK: - Test helpers


func fixtureString(for fixture: String) throws -> String {
    String(decoding: try fixtureData(for: fixture), as: UTF8.self)
}


func fixtureData(for fixture: String) throws -> Data {
    try Data(contentsOf: fixtureUrl(for: fixture))
}


func fixtureUrl(for fixture: String) -> URL {
    fixturesDirectory().appendingPathComponent(fixture)
}


func fixturesDirectory(path: String = #filePath) -> URL {
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


extension HTTPClient.Response {
    static func ok(fixture: String) throws -> Self {
        try .init(status: .ok, body: .init(data: fixtureData(for: fixture)))
    }
}
