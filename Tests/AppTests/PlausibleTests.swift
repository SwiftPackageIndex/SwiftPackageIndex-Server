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

import XCTest

@testable import App


final class PlausibleTests: XCTestCase {

    func test_User_identifier() throws {
        XCTAssertEqual(User.api(for: "token"), .init(name: "api", identifier: "3c469e9d"))
    }

    func test_props() throws {
        XCTAssertEqual(Plausible.props(for: nil), ["user": "none"])
        XCTAssertEqual(Plausible.props(for: .init(name: "api", identifier: "foo")), ["user": "foo"])
    }

    func test_postEvent_anonymous() async throws {
        Current.plausibleBackendReportingSiteID = { "foo.bar" }

        var called = false
        let client = MockClient { req, _ in
            called = true
            // validate
            XCTAssertEqual(try? req.content.decode(Plausible.Event.self),
                           .init(name: .pageview,
                                 url: "https://foo.bar/api/search",
                                 domain: "foo.bar",
                                 props: ["user": "none"]))
        }

        // MUT
        _ = try await Plausible.postEvent(client: client, kind: .pageview, path: .search, user: nil)

        XCTAssertTrue(called)
    }

    func test_postEvent_package() async throws {
        Current.plausibleBackendReportingSiteID = { "foo.bar" }

        let user = User(name: "api", identifier: "3c469e9d")
        var called = false
        let client = MockClient { req, _ in
            called = true
            // validate
            XCTAssertEqual(try? req.content.decode(Plausible.Event.self),
                           .init(name: .pageview,
                                 url: "https://foo.bar/api/packages/{owner}/{repository}",
                                 domain: "foo.bar",
                                 props: ["user": user.identifier]))
        }

        // MUT
        _ = try await Plausible.postEvent(client: client, kind: .pageview, path: .package, user: user)

        XCTAssertTrue(called)
    }
}
