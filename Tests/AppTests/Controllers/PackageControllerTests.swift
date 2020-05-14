@testable import App

import Vapor
import XCTest

class PackageControllerTests: AppTestCase {

    func test_index() throws {
        try app.test(.GET, "/packages") { response in
            XCTAssertEqual(response.status, .seeOther)
        }
    }

}
