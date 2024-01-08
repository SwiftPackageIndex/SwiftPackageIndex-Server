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

import Vapor


enum Mastodon {

    private static let instance = "mas.to"
    private static let apiURL = "https://\(instance)/api/v1/statuses"
    static let postMaxLength = 490  // 500, leaving some buffer for unicode accounting oddities

    struct Credentials {
        var accessToken: String
    }

    static func post(client: Client, message: String, encodedURL: (String) -> Void = { _ in }) async throws {
        guard let credentials = Current.mastodonCredentials() else {
            throw Social.Error.missingCredentials
        }

        let headers = HTTPHeaders([
            ("Authorization", "Bearer \(credentials.accessToken)"),
            ("Idempotency-Key", UUID().uuidString),
        ])

        struct Query: Encodable {
            var status: String
        }

        let res = try await client.post(URI(string: apiURL), headers: headers) { req in
            try req.query.encode(Query(status: message))
            encodedURL(req.url.string)
        }
        guard res.status == .ok else {
            throw Social.Error.requestFailed(res.status, res.body?.asString() ?? "")
        }
    }

}
