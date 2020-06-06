@testable import App

import SnapshotTesting
import XCTest


class RSSTests: XCTestCase {

    func test_render_item() throws {
        let item = RSSFeed.Item(title: "title", link: "link", content: "content")
        assertSnapshot(matching: item.node.render(indentedBy: .spaces(2)), as: .lines)
    }

    func test_render_feed() throws {
        // Test generated feed. The result should validate successfully
        // on https://validator.w3.org/feed/check.cgi
        let feed = RSSFeed(title: "feed title", description: "feed description",
                           link: "https://SwiftPackageIndex.com",
                           maxItemCount: 100,
                           items: [
                            RSSFeed.Item(title: "title",
                                         link: "https://SwiftPackageIndex.com/foo/bar",
                                         content: "content"),
                            RSSFeed.Item(title: "title",
                                         link: "https://SwiftPackageIndex.com/bar/baz",
                                         content: "content")]
        )
        assertSnapshot(matching: feed.rss.render(indentedBy: .spaces(2)),
                       as: .init(pathExtension: "xml", diffing: .lines))
    }

}
