@testable import App

import XCTest


class ViewUtilsTests: XCTestCase {
    
    func test_pluralizedCount() throws {
        XCTAssertEqual(pluralizedCount(0, singular: "executable"), "no executables")
        XCTAssertEqual(pluralizedCount(1, singular: "executable"), "1 executable")
        XCTAssertEqual(pluralizedCount(2, singular: "executable"), "2 executables")

        XCTAssertEqual(pluralizedCount(1, singular: "library", plural: "libraries"), "1 library")
        XCTAssertEqual(pluralizedCount(2, singular: "library", plural: "libraries"), "2 libraries")
        XCTAssertEqual(pluralizedCount(0, singular: "executable"), "no executables")

        XCTAssertEqual(pluralizedCount(0, singular: "executable", capitalized: true), "No executables")
        XCTAssertEqual(pluralizedCount(0, singular: "library", plural: "libraries", capitalized: true), "No libraries")
    }
    
    func test_pluralised() throws {
        XCTAssertEqual("version".pluralized(for: 0), "versions")
        XCTAssertEqual("version".pluralized(for: 1), "version")
        XCTAssertEqual("version".pluralized(for: 2), "versions")

        XCTAssertEqual("library".pluralized(for: 0, plural: "libraries"), "libraries")
        XCTAssertEqual("library".pluralized(for: 1, plural: "libraries"), "library")
        XCTAssertEqual("library".pluralized(for: 2, plural: "libraries"), "libraries")
    }

    func test_listPhrase() throws {
        // test listing 2 and 3 values
        XCTAssertEqual(listPhrase(nodes: ["A", "B"]).render(),
                       "A and B")
        XCTAssertEqual(listPhrase(nodes: ["A", "B", "C"]).render(),
                       "A, B, and C")
        // test opening
        XCTAssertEqual(listPhrase(opening: "Versions ", nodes: ["A", "B", "C"]).render(),
                       "Versions A, B, and C")
        // test closing
        XCTAssertEqual(listPhrase(nodes: ["A", "B", "C"], closing: ".").render(),
                       "A, B, and C.")
        // test empty list substitution
        XCTAssertEqual(listPhrase(nodes: [], ifEmpty: "none").render(),
                       "none")
        // test conjunction
        XCTAssertEqual(listPhrase(nodes: ["A", "B"], conjunction: " or ").render(),
                       "A or B")
        XCTAssertEqual(listPhrase(nodes: ["A", "B", "C"], conjunction: " or ").render(),
                       "A, B, or C")
    }
}
