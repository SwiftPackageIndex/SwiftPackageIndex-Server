@testable import App

import SnapshotTesting
import XCTest


class SitemapTests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        record = false
    }

    func test_render() throws {
        Current.siteURL = { "https://indexsite.com" }
        let s = SiteURL.siteMap()

        // MUT + validation
        assertSnapshot(matching: s.render(indentedBy: .spaces(2)),
                       as: .init(pathExtension: "xml", diffing: .lines))

    }

}
