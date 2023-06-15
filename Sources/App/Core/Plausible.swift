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
            case pageview
        }
    }

    enum Path: String {
        case badge = "/api/packages/{owner}/{repository}/badge"
        case package = "/api/packages/{owner}/{repository}"
        case packageCollections = "/api/package-collections"
        case search = "/api/search"
    }

    struct Error: Swift.Error {
        var message: String
    }

    static let postEventURI = URI(string: "https://plausible.io/api/event")

    static func postEvent(client: Client, kind: Event.Kind, path: Path, user: User?) async throws {
        guard let siteID = Current.plausibleAPIReportingSiteID() else {
            throw Error(message: "PLAUSIBLE_API_REPORTING_SITE_ID not set")
        }
        let res = try await client.post(postEventURI, headers: .applicationJSON) { req in
            try req.content.encode(Event(name: .pageview,
                                         url: "https://\(siteID)\(path.rawValue)",
                                         domain: siteID,
                                         props: user.props))
        }
        guard res.status.succeeded else {
            throw Error(message: "Request failed with status code: \(res.status)")
        }
    }

    static func props(for user: User?) -> [String: String] {
        switch user {
            case .none:
                return ["user": "none"]
            case .some(let wrapped):
                return ["user": wrapped.identifier]
        }

    }
}


private extension HTTPStatus {
    var succeeded: Bool { (200..<300).contains(self.code) }
}


private extension HTTPHeaders {
    static var applicationJSON: Self { .init([("Content-Type", "application/json")]) }
}


private extension Optional<User> {
    var props: [String: String] { Plausible.props(for: self) }
}
