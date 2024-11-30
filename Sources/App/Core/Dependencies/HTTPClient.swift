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

import Dependencies
import DependenciesMacros
import Vapor


@DependencyClient
struct HTTPClient {
    typealias Response = Vapor.HTTPClient.Response

    var fetchDocumentation: @Sendable (_ url: URI) async throws -> Response
}

extension HTTPClient: DependencyKey {
    static var liveValue: HTTPClient {
        .init(
            fetchDocumentation: { url in
                try await Vapor.HTTPClient.shared.get(url: url.string).get()
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
// Convenience initialiser to make testing easier
extension HTTPClient.Response {
    init(status: HTTPResponseStatus,
         version: HTTPVersion = .http1_1,
         headers: HTTPHeaders = .init(),
         body: ByteBuffer? = nil) {
        self.init(host: "host", status: status, version: version, headers: headers, body: body)
    }
}
#endif
