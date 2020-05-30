@testable import App

import XCTVapor

class ErrorPageModelTests: AppTestCase {

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
        let error = Abort(status)

        // MUT
        let model = ErrorPage.Model(status: status, error: error)

        // validate
        XCTAssertEqual(model.errorMessage, "500 - Internal Server Error")
    }

    func test_500_with_error_and_reason() throws {
        // setup
        let status = HTTPResponseStatus(statusCode: 500)
        let error = Abort(status, reason: "Reason")

        // MUT
        let model = ErrorPage.Model(status: status, error: error)

        // validate
        XCTAssertEqual(model.errorMessage, "500 - Internal Server Error - Reason")
    }

}
