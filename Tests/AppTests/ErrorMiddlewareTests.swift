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

import Vapor
import XCTest


class ErrorMiddlewareTests: AppTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()

        // set up some test routes
        app.get("ok") { _ in return "ok" }
        app.get("404") { req async throws -> Response in throw Abort(.notFound) }
        app.get("500") { req async throws -> Response in throw Abort(.internalServerError) }
    }

    func test_custom_routes() throws {
        // Test to ensure the test routes we've set up in setUpWithError are in effect
        try app.test(.GET, "ok", afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(response.body.asString(), "ok")
        })
    }

    func test_html_error() throws {
        // Test to ensure errors are converted to html error pages via the ErrorMiddleware
        try app.test(.GET, "404", afterResponse: { response in
            XCTAssertEqual(response.content.contentType, .html)
            XCTAssert(response.body.asString().contains("404 - Not Found"))
        })
    }

    func test_status_code() throws {
        // Ensure we're still reporting the actual status code even when serving html pages
        // (Status is important for Google ranking, see
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/323)
        try app.test(.GET, "404", afterResponse: { response in
            XCTAssertEqual(response.status, .notFound)
            XCTAssertEqual(response.content.contentType, .html)
        })
        try app.test(.GET, "500", afterResponse: { response in
            XCTAssertEqual(response.status, .internalServerError)
            XCTAssertEqual(response.content.contentType, .html)
        })
    }

}
