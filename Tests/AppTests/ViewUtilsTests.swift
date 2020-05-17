@testable import App

import XCTest


class ViewUtilsTests: XCTestCase {

    func test_pluralize() throws {
        XCTAssertEqual(pluralize(count: 0, singular: "executable"), "no executables")
        XCTAssertEqual(pluralize(count: 1, singular: "executable"), "1 executable")
        XCTAssertEqual(pluralize(count: 2, singular: "executable"), "2 executables")
        XCTAssertEqual(pluralize(count: 0, singular: "library", plural: "libraries"), "no libraries")
        XCTAssertEqual(pluralize(count: 1, singular: "library", plural: "libraries"), "1 library")
        XCTAssertEqual(pluralize(count: 2, singular: "library", plural: "libraries"), "2 libraries")
    }

}
