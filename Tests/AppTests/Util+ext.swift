import Foundation

#if canImport(WebKit)
import WebKit
#endif

@testable import App
import Fluent
import Plot
import SnapshotTesting
import XCTest


// MARK: - Useful extensions


extension XCTestCase {
    var isRunningInCI: Bool {
        ProcessInfo.processInfo.environment.keys.contains("GITHUB_WORKFLOW")
    }

    func assertEquals<Root, Value: Equatable>(_ keyPath: KeyPath<Root, Value>,
                                              _ value1: Root,
                                              _ value2: Root,
                                              file: StaticString = #file,
                                              line: UInt = #line) {
        XCTAssertEqual(value1[keyPath: keyPath],
                       value2[keyPath: keyPath],
                       "\(value1[keyPath: keyPath]) not equal to \(value2[keyPath: keyPath])",
                       file: file, line: line)
    }

    func assertEquals<Root, Value: Equatable>(_ values: [Root],
                                              _ keyPath: KeyPath<Root, Value>,
                                              _ expectations: [Value],
                                              file: StaticString = #file,
                                              line: UInt = #line) {
        XCTAssertEqual(values.map { $0[keyPath: keyPath] },
                       expectations,
                       "\(values.map { $0[keyPath: keyPath] }) not equal to \(expectations)",
                       file: file, line: line)
    }
}


extension URL: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        precondition(!value.isEmpty, "cannot convert empty string to URL")
        self = URL(string: value)!
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


extension String {
    var gh: String { "https://github.com/foo/\(self)" }
}


extension Array where Element == String {
    var gh: Self { map(\.gh) }
}


extension Array where Element: FluentKit.Model {
    public func save(on database: Database) -> EventLoopFuture<Void> {
        map {
            $0.save(on: database)
        }.flatten(on: database.eventLoop)
    }
}


#if os(macOS)
extension Snapshotting where Value == HTML, Format == NSImage {
    public static func image(precision: Float = 1, size: CGSize? = nil) -> Snapshotting {
        Snapshotting<NSView, NSImage>.image(precision: precision, size: size).pullback { node in
            let html = node.render()
            let webView = WKWebView()
            webView.loadHTMLString(html, baseURL: nil)
            return webView
        }
    }
}
#endif
