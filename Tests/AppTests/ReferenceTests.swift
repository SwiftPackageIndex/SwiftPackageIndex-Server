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

    func test_decode_legacyData() throws {
        // Ensure we load old data
        let json = Data(#"{"tag": {"build": "", "major": 0, "minor": 1, "patch": 0, "preRelease": ""}}"#.utf8)
        let decoded = try JSONDecoder().decode(Reference.self, from: json)
        XCTAssertEqual(decoded, .tag(.init(0, 1, 0), nil))
    }

}
