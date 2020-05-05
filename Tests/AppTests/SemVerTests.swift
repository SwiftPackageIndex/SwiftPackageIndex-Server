@testable import App

import XCTest

class SemVerTests: XCTestCase {

    func test_parse() throws {
        XCTAssertEqual(SemVer.parse("1.2.3"), SemVer(major: 1, minor: 2, patch: 3))
        XCTAssertEqual(SemVer.parse("1.2"), SemVer(major: 1, minor: 2, patch: 0))
        XCTAssertEqual(SemVer.parse("1"), SemVer(major: 1, minor: 0, patch: 0))
        XCTAssertEqual(SemVer.parse(""), nil)
        XCTAssertEqual(SemVer.parse("1.2.3rc"), nil)
    }

    func test_isValid() throws {
        XCTAssert(SemVer.isValid("1.2.3"))
        XCTAssert(!SemVer.isValid("swift-2.2-SNAPSHOT-2016-01-11-a"))
    }
}
