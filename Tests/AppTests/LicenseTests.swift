@testable import App

import XCTVapor


class LicenseTests: XCTestCase {

    func test_init_from_dto() throws {
        XCTAssertEqual(License(from: Github.License(key: "mit")), .mit)
        XCTAssertEqual(License(from: Github.License(key: "agpl-3.0")), .agpl_3_0)
        XCTAssertEqual(License(from: Github.License(key: "other")), .other)
        XCTAssertEqual(License(from: .none), .none)
    }

    func test_init_from_dto_unknown() throws {
        // ensure unknown licenses are mapped to `.other`
        XCTAssertEqual(License(from: Github.License(key: "non-existing license")), .other)
    }

}
