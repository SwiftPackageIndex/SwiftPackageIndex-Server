@testable import App

import SnapshotTesting
import XCTVapor


class SitemapTests: AppTestCase {

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

    func test_sitemap_route() throws {
        try app.test(.GET, "sitemap.xml") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType,
                           .some(.init(type: "text", subType: "xml")))
        }
    }

}
