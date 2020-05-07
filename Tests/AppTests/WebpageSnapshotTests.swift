@testable import App

import SnapshotTesting
import XCTest


let defaultSize = CGSize(width: 800, height: 600)

class WebpageSnapshotTests: XCTestCase {
    func test_home() throws {
        let html = HTML.render(homePage())
        assertSnapshot(matching: html, as: .lines)

        #if os(macOS)
        if !isRunningInCI {
          assertSnapshot(matching: homePage(), as: .image(size: defaultSize))
        }
        #endif
    }
}
