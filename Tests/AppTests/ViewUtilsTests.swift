@testable import App

import XCTest


class ViewUtilsTests: XCTestCase {

    func test_pluralizeCount() throws {
        XCTAssertEqual(pluralizedCount(0, singular: "executable"), "no executables")
        XCTAssertEqual(pluralizedCount(1, singular: "executable"), "1 executable")
        XCTAssertEqual(pluralizedCount(2, singular: "executable"), "2 executables")
        XCTAssertEqual(pluralizedCount(0, singular: "library", plural: "libraries"), "no libraries")
        XCTAssertEqual(pluralizedCount(1, singular: "library", plural: "libraries"), "1 library")
        XCTAssertEqual(pluralizedCount(2, singular: "library", plural: "libraries"), "2 libraries")
    }

    func test_pluralised() throws {
        XCTAssertEqual("version".pluralized(for: 0), "versions")
        XCTAssertEqual("version".pluralized(for: 1), "version")
        XCTAssertEqual("version".pluralized(for: 2), "versions")
        XCTAssertEqual("library".pluralized(for: 0, plural: "libraries"), "libraries")
        XCTAssertEqual("library".pluralized(for: 1, plural: "libraries"), "library")
        XCTAssertEqual("library".pluralized(for: 2, plural: "libraries"), "libraries")
    }
}
