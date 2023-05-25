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

    func test_apiID() throws {
        XCTAssertEqual(Plausible.apiID(for: .open), ["apiID": "open"])
        XCTAssertEqual(Plausible.apiID(for: .token("token")), ["apiID": "3c469e9d"])
    }

    func test_postEvent() async throws {
        Current.plausibleAPIReportingSiteID = { "foo.bar" }

        var called = false
        let client = MockClient { req, _ in
            called = true
            // validate
            XCTAssertEqual(try? req.content.decode(Plausible.Event.self),
                           .init(name: .api,
                                 url: "https://foo.bar/api/search",
                                 domain: "foo.bar",
                                 props: ["apiID": "open"]))
        }

        // MUT
        _ = try await Plausible.postEvent(client: client, kind: .api, path: .search, apiKey: .open)

        XCTAssertTrue(called)
    }

}
