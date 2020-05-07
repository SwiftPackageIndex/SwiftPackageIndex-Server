import Foundation

#if canImport(WebKit)
import WebKit
#endif

@testable import App
import Fluent
import SnapshotTesting
import XCTest


// MARK: - Useful extensions


extension XCTestCase {
    var isRunningInCI: Bool {
        ProcessInfo.processInfo.environment.keys.contains("GITHUB_WORKFLOW")
    }
}


extension String {
    var url: URL {
        URL(string: self)!
    }
}


extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }
}


extension Array where Element: FluentKit.Model {
    public func save(on database: Database) -> EventLoopFuture<Void> {
        map {
            $0.save(on: database)
        }.flatten(on: database.eventLoop)
    }
}


#if os(macOS)
extension Snapshotting where Value == HTML.Node, Format == NSImage {
    public static func image(precision: Float = 1, size: CGSize? = nil) -> Snapshotting {
        Snapshotting<NSView, NSImage>.image(precision: precision, size: size).pullback { node in
            let html = HTML.render(node)
            let webView = WKWebView()
            webView.loadHTMLString(html, baseURL: nil)
            return webView
        }
    }
}
#endif
