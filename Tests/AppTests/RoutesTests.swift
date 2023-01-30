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

@testable import App

import XCTVapor


final class RoutesTests: AppTestCase {

    func test_documentation_images() async throws {
        // setup
        Current.fetchDocumentation = { _, uri in
            // embed uri.path in the body as a simple way to test the requested url
            .init(status: .ok, body: .init(string: uri.path))
        }

        // MUT
        try app.test(.GET, "foo/bar/1.2.3/images/baz.png") {
            // validation
            XCTAssertEqual($0.status, .ok)
            XCTAssertEqual($0.content.contentType?.description, "application/octet-stream")
            XCTAssertEqual($0.body.asString(), "/foo/bar/1.2.3/images/baz.png")
        }
        try app.test(.GET, "foo/bar/1.2.3/images/BAZ.png") {
            // validation
            XCTAssertEqual($0.status, .ok)
            XCTAssertEqual($0.content.contentType?.description, "application/octet-stream")
            XCTAssertEqual($0.body.asString(), "/foo/bar/1.2.3/images/BAZ.png")
        }
    }

    func test_documentation_img() async throws {
        // setup
        Current.fetchDocumentation = { _, _ in .init(status: .ok) }

        // MUT
        try app.test(.GET, "foo/bar/1.2.3/img/baz.png") { res in
            // validation
            XCTAssertEqual(res.status, .ok)
        }
    }

}
