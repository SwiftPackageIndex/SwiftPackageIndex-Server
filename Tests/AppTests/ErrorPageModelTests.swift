@testable import App

import XCTVapor

class ErrorPageModelTests: AppTestCase {

    func test_404() throws {
        // setup
        let status = HTTPResponseStatus(statusCode: 404)

        // MUT
        let model = ErrorPage.Model(status: status, error: nil)

        // validate
        XCTAssertEqual(model.errorMessage, "404 - Not Found")
    }

    func test_500_without_error() throws {
        // setup
        let status = HTTPResponseStatus(statusCode: 500)

        // MUT
        let model = ErrorPage.Model(status: status, error: nil)

        // validate
        XCTAssertEqual(model.errorMessage, "500 - Internal Server Error")
    }

    func test_500_with_error() throws {
        // setup
        let status = HTTPResponseStatus(statusCode: 500)
        let error: AbortError = nil // I need an AbortError here but don't want to stand up the whole stack just to test the view model.

        // MUT
        let model = ErrorPage.Model(status: status, error: error)

        // validate
        XCTAssertEqual(model.errorMessage, "500 - Internal Server Error - Reason")
    }

}
