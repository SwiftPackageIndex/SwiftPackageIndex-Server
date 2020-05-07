@testable import App

import SnapshotTesting
import XCTest

#if canImport(WebKit)
import WebKit
#endif


class WebpageSnapshotTests: XCTestCase {

    func test_home() throws {
        let html = HTML.render(homePage())
        assertSnapshot(matching: html, as: .lines)

        #if os(iOS) || os(macOS)
        let webView = WKWebView()
        webView.loadHTMLString(html, baseURL: nil)
        if !ProcessInfo.processInfo.environment.keys.contains("GITHUB_WORKFLOW") {
          assertSnapshot(
            matching: webView,
            as: .image(size: .init(width: 800, height: 600))
          )
        }
        #endif

    }

}
