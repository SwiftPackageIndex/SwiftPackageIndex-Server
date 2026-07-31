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
import Foundation
import SotoS3
import SotoCore
import SotoSignerV4


@DependencyClient
struct HTTPClient {
    typealias Request = Vapor.HTTPClient.Request
    typealias Response = Vapor.HTTPClient.Response

    var get: @Sendable (_ url: String, _ headers: HTTPHeaders) async throws -> Response
    var post: @Sendable (_ url: String, _ headers: HTTPHeaders, _ body: Data?) async throws -> Response

    var fetchDocumentation: @Sendable (_ url: URI) async throws -> Response
    var fetchDocumentationWithIAM: @Sendable (_ url: URI) async throws -> Response
    var fetchHTTPStatusCode: @Sendable (_ url: String) async throws -> HTTPStatus
    var mastodonPost: @Sendable (_ message: String) async throws -> Void
    var postAnalyticsEvent: @Sendable (_ kind: Analytics.Event.Kind, _ path: Analytics.Path, _ user: User?) async throws -> Void
}

extension HTTPClient: DependencyKey {
    static var liveValue: HTTPClient {
        .init(
            get: { url, headers in
                let req = try Request(url: url, method: .GET, headers: headers)
                return try await shared.execute(request: req).get()
            },
            post: { url, headers, body in
                let req = try Request(url: url, method: .POST, headers: headers, body: body.map({.data($0)}))
                return try await Vapor.HTTPClient.shared.execute(request: req).get()
            },
            fetchDocumentation: { url in
                try await Vapor.HTTPClient.shared.get(url: url.string).get()
            },
            fetchDocumentationWithIAM: { url in
                try await Self.fetchWithIAMAuth(url: url)
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
            postAnalyticsEvent: { kind, path, user in
                try await Analytics.postEvent(kind: kind, path: path, user: user)
            }
        )
    }

    func get(url: String) async throws -> Response { try await get(url: url, headers: .init()) }
    func post(url: String, body: Data?) async throws -> Response {
        try await post(url: url, headers: .init(), body: body)
    }

    private static var shared: Vapor.HTTPClient { globallySharedHTTPClient }
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


private let globallySharedHTTPClient: Vapor.HTTPClient = {
    var conf = Vapor.HTTPClient.Configuration.singletonConfiguration
    // 2026-04-14 sas: Increasing limit from default `.enabled(limit: .ratio(25))`, which caused requests to fail in the past.
    // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/4024#issuecomment-4237684071
    conf.decompression = .enabled(limit: .size(Constants.httpDecompressionSizeLimit))

    let httpClient = Vapor.HTTPClient(
        eventLoopGroup: Vapor.HTTPClient.defaultEventLoopGroup,
        configuration: conf,
        backgroundActivityLogger: .noop
    )
    return httpClient
}()


// MARK: - AWS IAM Authentication
extension HTTPClient {
    static func fetchWithIAMAuth(url: URI) async throws -> Response {
        // Create AWS client with default credential provider
        let awsClient = AWSClient(
            credentialProvider: .default,
            httpClientProvider: .createNew
        )

        return try await run {
            // Extract region from URL
            let urlComponents = URLComponents(string: url.string)
            guard let host = urlComponents?.host else {
                throw AppError.genericError(nil, "Invalid URL: \(url.string)")
            }

            let region = extractRegionFromHost(host) ?? .useast2

            // Get credentials from the credential provider
            let credentials: Credential
            do {
                credentials = try await awsClient.credentialProvider.getCredential(
                    on: awsClient.eventLoopGroup.next(),
                    logger: Logger(label: "aws-credentials")
                ).get()
            } catch {
                throw AppError.genericError(nil, "Failed to retrieve AWS credentials: \(error)")
            }

            // Use Soto's AWSSigner to sign the request headers
            let signer = AWSSigner(
                credentials: credentials,
                name: "execute-api",
                region: region.rawValue
            )

            // Create the request URL
            guard let requestURL = URL(string: url.string) else {
                throw AppError.genericError(nil, "Invalid URL: \(url.string)")
            }

            // Sign the headers for the request
            let signedHeaders: HTTPHeaders
            signedHeaders = signer.signHeaders(
                url: requestURL,
                method: HTTPMethod.GET,
                headers: HTTPHeaders(),
                body: nil
            )

            // Create request with signed headers
            let request = try Request(url: url.string, method: .GET, headers: signedHeaders)

            // Execute the request
            return try await shared.execute(request: request).get()
        } defer: {
            try await awsClient.shutdown()
        }
    }

    private static func extractRegionFromHost(_ host: String) -> Region? {
        // Extract region from API Gateway URL format: {api-id}.execute-api.{region}.amazonaws.com
        let components = host.split(separator: ".")
        if components.count >= 4 && components[1] == "execute-api" && components[3] == "amazonaws" {
            let regionString = String(components[2])
            return Region(rawValue: regionString)
        }
        return nil
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

    static var noop: @Sendable (_ kind: Analytics.Event.Kind, _ path: Analytics.Path, _ user: User?) async throws -> Void {
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
