@testable import App

import SnapshotTesting
import XCTest


class WebpageSnapshotTests: XCTestCase {

    func test_home() throws {
        let home = HTML.render(homePage())
        assertSnapshot(matching: home, as: .lines)
    }

}
