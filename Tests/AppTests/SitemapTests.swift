@testable import App

import SnapshotTesting
import XCTVapor


class SitemapTests: AppTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        record = false
    }

    func test_render() throws {
        // setup
        Current.siteURL = { "https://indexsite.com" }
        let packages = [("foo1", "bar1"), ("foo2", "bar2"), ("foo3", "bar3")]

        // MUT
        let xml = SiteURL.siteMap(with: packages).render(indentedBy: .spaces(2))

        // MUT + validation
        assertSnapshot(matching: xml, as: .init(pathExtension: "xml", diffing: .lines))
    }

    func test_sitemap_route() throws {
        try app.test(.GET, "sitemap.xml") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType,
                           .some(.init(type: "text", subType: "xml")))
            let xml = try XCTUnwrap(res.body.asString())
            assertSnapshot(matching: xml, as: .init(pathExtension: "xml", diffing: .lines))
        }
    }

}
