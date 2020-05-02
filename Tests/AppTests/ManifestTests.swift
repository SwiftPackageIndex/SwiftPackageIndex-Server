//
@testable import App

import XCTest


class ManifestTests: XCTestCase {

    func test_decode() throws {
        let data = try loadData(for: "manifest-1.json")
        let m = try JSONDecoder().decode(Manifest.self, from: data)
        XCTAssertEqual(m.name, "SPI-Server")
    }

}
