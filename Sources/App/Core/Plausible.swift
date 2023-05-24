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


enum Plausible {
    struct Event: Content, Equatable {
        var name: Kind
        var url: String
        var domain: String
        var props: [String: String]

        enum Kind: String, Content, Equatable {
            case api
            case pageview
        }
    }

    enum Path: String {
        case badge = "/api/packages/{owner}/{repository}/badge"
        case search = "/api/search"
    }

    enum APIKey {
        case open
        case token(String)
    }

    struct Error: Swift.Error {
        var message: String
    }

    static let postEventURI = URI(string: "https://plausible.io/api/event")

    static func postEvent(client: Client, kind: Event.Kind, path: Path, apiKey: APIKey) async throws {
        guard let siteID = Current.plausibleSiteID() else { throw Error(message: "PLAUSIBLE_SITE_ID not set") }
        let res = try await client.post(postEventURI, headers: .applicationJSON) { req in
            try req.content.encode(Event(name: .api,
                                         url: "https://\(siteID)\(path.rawValue)",
                                         domain: siteID,
                                         props: .apiID(for: apiKey)))
        }
        guard res.status.succeeded else {
            throw Error(message: "Request failed with status code: \(res.status)")
        }
    }

    static func postEvent(req: Request, kind: Event.Kind, path: Path, apiKey: APIKey) {
        Task {
            do {
                try await Current.postPlausibleEvent(req.client, kind, path, apiKey)
            } catch {
                Current.logger().warning("Plausible.postEvent failed: \(error)")
            }
        }
    }

    static func apiID(for apiKey: APIKey) -> [String: String] {
        switch apiKey {
            case .open:
                return ["apiID": "open"]
            case let .token(token):
                return ["apiID": String(token.sha256Checksum.prefix(8))]
        }
    }
}


private extension HTTPStatus {
    var succeeded: Bool { (200..<300).contains(self.code) }
}


private extension HTTPHeaders {
    static var applicationJSON: Self { .init([("Content-Type", "application/json")]) }
}


private extension [String: String] {
    static func apiID(for apiKey: Plausible.APIKey) -> Self { Plausible.apiID(for: apiKey) }
}
