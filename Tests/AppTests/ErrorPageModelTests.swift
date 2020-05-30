@testable import App

import XCTVapor

class ErrorPageModelTests: AppTestCase {

    func test_500() throws {
        // setup
        let error = Abort(.internalServerError)

        // MUT
        let model = ErrorPage.Model(error)

        // validate
        XCTAssertEqual(model.errorMessage, "500 - Internal Server Error")
    }

    func test_500_with_reason() throws {
        // setup
        let error = Abort(.internalServerError, reason: "Reason")

        // MUT
        let model = ErrorPage.Model(error)

        // validate
        XCTAssertEqual(model.errorMessage, "500 - Internal Server Error - Reason")
    }

}
