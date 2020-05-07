@testable import App

import SnapshotTesting
import XCTest

#if canImport(WebKit)
import WebKit
#endif


let defaultSize = CGSize(width: 800, height: 600)

class WebpageSnapshotTests: XCTestCase {
    func test_home() throws {
        let html = HTML.render(homePage())
        assertSnapshot(matching: html, as: .lines)

        #if os(iOS) || os(macOS)
        let webView = WKWebView()
        webView.loadHTMLString(html, baseURL: nil)
        if !isRunningInCI {
          assertSnapshot(matching: webView, as: .image(size: defaultSize))
        }
        #endif

    }
}
