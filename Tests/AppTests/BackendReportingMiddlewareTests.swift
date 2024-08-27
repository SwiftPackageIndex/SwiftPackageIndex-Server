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

import XCTVapor
import NIOConcurrencyHelpers
@testable import App

final class BackendReportingMiddlewareTests: XCTestCase {

    func testMaintainerPageViewTriggersPlausibleEvent() async throws {
        let app = Application(.testing)

        /// Defer to shutdown the app asynchronously after the test completes
        defer {
            Task {
                await app.shutdown()
            }
        }

        try await configure(app)

        var intercepted = false
        let mockClient = MockClient { req, res in
            intercepted = true
            res.status = .ok
        }

        /// Ensure Current is using the MockClient
        Current.setHTTPClient(mockClient)

        /// Trigger a request
        try app.test(.GET, "/schwa/Compute/information-for-package-maintainers") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertTrue(res.body.string.contains("Information for Compute Maintainers"))
        }

        /// Await to give time for async tasks
        try await Task.sleep(nanoseconds: 5_000_000_000)

        XCTAssertTrue(intercepted, "The request was not intercepted by MockClient")
    }
}
