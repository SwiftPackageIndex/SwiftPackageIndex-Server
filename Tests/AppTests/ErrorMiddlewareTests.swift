@testable import App

import Vapor
import XCTest


class ErrorMiddlewareTests: AppTestCase {

    func test_html_error() throws {
        // Test to ensure errors are converted to html error pages via the ErrorMiddleware
        try app.test(.GET, "/packages/CAFECAFE-CAFE-CAFE-CAFE-CAFECAFECAFE") { response in
            // Ensure we're getting html content and status ok back
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(response.content.contentType, .html)
        }
    }

}
