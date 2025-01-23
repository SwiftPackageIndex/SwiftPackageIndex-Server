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
    typealias Request = Vapor.HTTPClient.Request
    typealias Response = Vapor.HTTPClient.Response

    var get: @Sendable (_ url: String, _ headers: HTTPHeaders) async throws -> Response
    var post: @Sendable (_ url: String, _ headers: HTTPHeaders, _ body: Data?) async throws -> Response

    var fetchDocumentation: @Sendable (_ url: URI) async throws -> Response
    var fetchHTTPStatusCode: @Sendable (_ url: String) async throws -> HTTPStatus
    var mastodonPost: @Sendable (_ message: String) async throws -> Void
    var postPlausibleEvent: @Sendable (_ kind: Plausible.Event.Kind, _ path: Plausible.Path, _ user: User?) async throws -> Void
}

extension HTTPClient: DependencyKey {
    static var liveValue: HTTPClient {
        .init(
            get: { url, headers in
                let req = try Request(url: url, method: .GET, headers: headers)
                return try await Vapor.HTTPClient.shared.execute(request: req).get()
            },
            post: { url, headers, body in
                let req = try Request(url: url, method: .POST, headers: headers, body: body.map({.data($0)}))
                return try await Vapor.HTTPClient.shared.execute(request: req).get()
            },
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
            },
            mastodonPost: { message in try await Mastodon.post(message: message) },
            postPlausibleEvent: { kind, path, user in
                try await Plausible.postEvent(kind: kind, path: path, user: user)
            }
        )
    }

    func get(url: String) async throws -> Response { try await get(url: url, headers: .init()) }
    func post(url: String, body: Data?) async throws -> Response {
        try await post(url: url, headers: .init(), body: body)
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

    static var noop: @Sendable (_ kind: Plausible.Event.Kind, _ path: Plausible.Path, _ user: User?) async throws -> Void {
        { _, _, _ in }
    }
}

extension HTTPClient.Response {
    init(status: HTTPResponseStatus,
         version: HTTPVersion = .http1_1,
         headers: HTTPHeaders = .init(),
         body: ByteBuffer? = nil) {
        self.init(host: "host", status: status, version: version, headers: headers, body: body)
    }

    static var badRequest: Self { .init(status: .badRequest) }
    static var notFound: Self { .init(status: .notFound) }
    static var tooManyRequests: Self { .init(status: .tooManyRequests) }
    static var ok: Self { .init(status: .ok) }
    static var created: Self { .init(status: .created) }

    static func ok(body: String, headers: HTTPHeaders = .init()) -> Self {
        .init(status: .ok, headers: headers, body: .init(string: body))
    }

    static func ok<T: Encodable>(jsonEncode value: T, headers: HTTPHeaders = .init()) throws -> Self {
        let data = try JSONEncoder().encode(value)
        return .init(status: .ok, headers: headers, body: .init(data: data))
    }

    static func created<T: Encodable>(jsonEncode value: T, headers: HTTPHeaders = .init()) throws -> Self {
        let data = try JSONEncoder().encode(value)
        return .init(status: .created, headers: headers, body: .init(data: data))
    }
}
#endif
