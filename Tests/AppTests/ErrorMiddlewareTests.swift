@testable import App

import Vapor
import XCTest


class ErrorMiddlewareTests: AppTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()

        // set up some test routes
        app.get("ok") { _ in return "ok" }
        app.get("404") { req -> EventLoopFuture<Response> in throw Abort(.notFound) }
        app.get("500") { req -> EventLoopFuture<Response> in throw Abort(.internalServerError) }
    }

    func test_custom_routes() throws {
        // Test to ensure the test routes we've set up in setUpWithError are in effect
        try app.test(.GET, "ok") { response in
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(response.body.asString(), "ok")
        }
    }

    func test_html_error() throws {
        // Test to ensure errors are converted to html error pages via the ErrorMiddleware
        try app.test(.GET, "404") { response in
            // Ensure we're getting html content and status ok back
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(response.content.contentType, .html)
            XCTAssert(response.body.asString()!.contains("404 - Not Found"))
        }
    }

    func test_404_alert() throws {
        // Test to ensure 404s do *not* trigger a Rollbar alert
        var errorReported = false
        Current.reportError = { _, level, error in
            errorReported = true
            return .just(value: ())
        }

        try app.test(.GET, "404") { response in
            XCTAssertFalse(errorReported)
        }
    }

    func test_500_alert() throws {
        // Test to ensure 500s *do* trigger a Rollbar alert
        var reportedLevel: AppError.Level? = nil
        var reportedError: String? = nil
        Current.reportError = { _, level, error in
            reportedLevel = level
            reportedError = error.localizedDescription
            return .just(value: ())
        }

        try app.test(.GET, "500") { response in
            XCTAssertEqual(reportedLevel, .critical)
            XCTAssertEqual(reportedError, Abort(.internalServerError).localizedDescription)
        }
    }

}


extension ByteBuffer {
    func asString() -> String? {
        getString(at: 0, length: readableBytes)
    }
}
