//
@testable import App

import XCTest


class ManifestTests: XCTestCase {

    func test_decode_1() throws {
        let data = try loadData(for: "manifest-1.json")
        let m = try JSONDecoder().decode(Manifest.self, from: data)
        XCTAssertEqual(m.name, "SPI-Server")
    }

    func test_decode_2() throws {
        let data = try loadData(for: "PromiseKit.json")
        let m = try JSONDecoder().decode(Manifest.self, from: data)
        XCTAssertEqual(m.name, "PromiseKit")
        XCTAssertEqual(m.swiftLanguageVersions, ["4", "4.2", "5"])
    }

}
