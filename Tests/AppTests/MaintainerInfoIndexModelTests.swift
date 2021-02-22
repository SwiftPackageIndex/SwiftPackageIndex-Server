@testable import App

import XCTVapor
import SnapshotTesting


class MaintainerInfoIndexModelTests: SnapshotTestCase {

    func test_badgeURL() throws {
        Current.siteURL = { "https://spi.com" }
        let model = MaintainerInfoIndex.Model.mock

        XCTAssertEqual(model.badgeURL(for: .swiftVersions), "https://img.shields.io/endpoint?url=https%3A%2F%2Fspi.com%2Fapi%2Fpackages%2Fexample%2Fpackage%2Fbadge%3Ftype%3Dswift-versions")
        XCTAssertEqual(model.badgeURL(for: .platforms), "https://img.shields.io/endpoint?url=https%3A%2F%2Fspi.com%2Fapi%2Fpackages%2Fexample%2Fpackage%2Fbadge%3Ftype%3Dplatforms")
    }

    func test_badgeMarkdown() throws {
        // Test badge markdown structure
        Current.siteURL = { "https://spi.com" }
        let model = MaintainerInfoIndex.Model.mock

        let badgeURL = model.badgeURL(for: .swiftVersions)
        XCTAssertEqual(model.badgeMarkdown(for: .swiftVersions), "[![](\(badgeURL))](https://spi.com/example/package)")
    }
}
