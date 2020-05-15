@testable import App

import SnapshotTesting
import XCTest


let defaultSize = CGSize(width: 800, height: 600)

class WebpageSnapshotTests: XCTestCase {
    func test_home() throws {
        // record = true
        assertSnapshot(matching: PublicPage.admin().render(indentedBy: .spaces(2)), as: .lines)

        #if os(macOS)
        if !isRunningInCI {
            assertSnapshot(matching: PublicPage.admin(), as: .image(size: defaultSize))
        }
        #endif
    }
}
