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

import AsyncHTTPClient
import Dependencies
import DependenciesMacros
import Vapor


@DependencyClient
struct HTTPClient {
    typealias Response = Vapor.HTTPClient.Response

    var fetchDocumentation: @Sendable (_ url: URI) async throws -> Response = { _ in XCTFail("fetchDocumentation"); return .ok }
    var fetchHTTPStatusCode: @Sendable (_ url: String) async throws -> HTTPStatus = { _ in XCTFail("fetchHTTPStatusCode"); return .ok }
}

extension HTTPClient: DependencyKey {
    static var liveValue: HTTPClient {
        .init(
            fetchDocumentation: { url in
                try await Vapor.HTTPClient.shared.get(url: url.string).get()
            },
            fetchHTTPStatusCode: { url in
                var config = Vapor.HTTPClient.Configuration()
                // We're forcing HTTP/1 due to a bug in Github's HEAD request handling
                // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1676
                config.httpVersion = .http1Only
                let client = Vapor.HTTPClient(eventLoopGroupProvider: .singleton, configuration: config)
                return try await run {
                    var req = HTTPClientRequest(url: url)
                    req.method = .HEAD
                    return try await client.execute(req, timeout: .seconds(2)).status
                } defer: {
                    try await client.shutdown()
                }
            }
        )
    }
}


extension HTTPClient: TestDependencyKey {
    static var testValue: Self { Self() }
}


extension DependencyValues {
    var httpClient: HTTPClient {
        get { self[HTTPClient.self] }
        set { self[HTTPClient.self] = newValue }
    }
}


#if DEBUG
// Convenience initialisers to make testing easier

extension HTTPClient {
    static func echoURL(headers: HTTPHeaders = .init()) -> @Sendable (_ url: URI) async throws -> Response {
        { url in
            // echo url.path in the body as a simple way to test the requested url
                .init(status: .ok, headers: headers, body: .init(string: url.path))
        }
    }
}

extension HTTPClient.Response {
    init(status: HTTPResponseStatus,
         version: HTTPVersion = .http1_1,
         headers: HTTPHeaders = .init(),
         body: ByteBuffer? = nil) {
        self.init(host: "host", status: status, version: version, headers: headers, body: body)
    }

    static var ok: Self { .init(status: .ok) }
    static var notFound: Self { .init(status: .notFound) }
    static var badRequest: Self { .init(status: .badRequest) }
}
#endif
