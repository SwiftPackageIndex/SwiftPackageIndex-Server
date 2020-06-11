@testable import App

import XCTest


class ReferenceTests: XCTestCase {

    func test_Codable() throws {
        do { // branch
            let ref = Reference.branch("foo")
            let json = try JSONEncoder().encode(ref)
            let decoded = try JSONDecoder().decode(Reference.self, from: json)
            XCTAssertEqual(decoded, .branch("foo"))
        }
        do { // tag
            let ref = Reference.tag(.init(1, 2, 3))
            let json = try JSONEncoder().encode(ref)
            let decoded = try JSONDecoder().decode(Reference.self, from: json)
            XCTAssertEqual(decoded, .tag(.init(1, 2, 3)))
        }
    }

    func test_isRelease() throws {
        XCTAssertTrue(Reference.tag(.init(1, 0, 0)).isRelease)
        XCTAssertFalse(Reference.tag(.init(1, 0, 0, "beta1")).isRelease)
        XCTAssertFalse(Reference.branch("main").isRelease)
    }

}
