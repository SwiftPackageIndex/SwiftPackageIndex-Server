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
import Dependencies


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
        case dependencies = "/api/dependencies"
        case package = "/api/packages/{owner}/{repository}"
        case packageCollections = "/api/package-collections"
        case rss = "/rss"
        case search = "/api/search"
        case sitemapIndex = "/sitemap-index"
        case sitemapStaticPages = "/sitemap-static"
        case sitemapPackage = "/{owner}/{repository}/sitemap"
    }

    struct Error: Swift.Error {
        var message: String
    }

    static let postEventURL = "https://plausible.io/api/event"

    static func postEvent(kind: Event.Kind, path: Path, user: User?) async throws {
        @Dependency(\.environment) var environment
        guard let siteID = environment.plausibleBackendReportingSiteID() else {
            throw Error(message: "PLAUSIBLE_BACKEND_REPORTING_SITE_ID not set")
        }
        let body = try JSONEncoder().encode(Event(name: .pageview,
                                                  url: "https://\(siteID)\(path.rawValue)",
                                                  domain: siteID,
                                                  props: user.props))
        @Dependency(\.httpClient) var httpClient
        let res = try await httpClient.post(url: postEventURL, headers: .applicationJSON, body: body)
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
