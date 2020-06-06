@testable import App

import SnapshotTesting
import XCTest


class RSSTests: XCTestCase {

    func test_render_item() throws {
        let item = RSSFeed.Item(title: "title", link: "link", content: "content")
        assertSnapshot(matching: item.node.render(indentedBy: .spaces(2)),
                       as: .lines)
    }

}
