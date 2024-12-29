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
import Vapor


enum Mastodon {

    private static let instance = "mas.to"
    private static let apiURL = "https://\(instance)/api/v1/statuses"
    static let postMaxLength = 490  // 500, leaving some buffer for unicode accounting oddities

    struct Credentials {
        var accessToken: String
    }

    static func post(message: String) async throws {
        @Dependency(\.environment) var environment
        @Dependency(\.httpClient) var httpClient
        @Dependency(\.uuid) var uuid
        guard let credentials = environment.mastodonCredentials() else {
            throw Social.Error.missingCredentials
        }

        let headers = HTTPHeaders([
            ("Authorization", "Bearer \(credentials.accessToken)"),
            ("Idempotency-Key", uuid().uuidString),
        ])

        struct Query: Encodable {
            var status: String
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = Mastodon.instance
        components.path = "/api/v1/statuses"
        components.queryItems = [URLQueryItem(name: "status", value: message)]
        guard let url = components.string else {
            throw Social.Error.invalidURL
        }
        let res = try await httpClient.post(url: url, headers: headers, body: nil)

        guard res.status == .ok else {
            throw Social.Error.requestFailed(res.status, res.body?.asString() ?? "")
        }
    }

}
