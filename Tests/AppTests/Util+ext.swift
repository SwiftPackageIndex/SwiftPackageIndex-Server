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
                       file: (file), line: line)
    }

    func assertEquals<Root, Value: Equatable>(_ values: [Root],
                                              _ keyPath: KeyPath<Root, Value>,
                                              _ expectations: [Value],
                                              file: StaticString = #file,
                                              line: UInt = #line) {
        XCTAssertEqual(values.map { $0[keyPath: keyPath] },
                       expectations,
                       "\(values.map { $0[keyPath: keyPath] }) not equal to \(expectations)",
                       file: (file), line: line)
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
    var asGithubUrl: String { "https://github.com/foo/\(self)" }
    var asSwiftVersion: SwiftVersion { SwiftVersion(self)! }
}


extension Array where Element == String {
    var asURLs: [URL] { compactMap(URL.init(string:)) }
    var asGithubUrls: Self { map(\.asGithubUrl) }
    var asSwiftVersions: [SwiftVersion] { map(\.asSwiftVersion) }
}


extension Snapshotting where Value == () -> HTML, Format == String {
    public static var html: Snapshotting {
        Snapshotting<String, String>.lines.pullback { node in
            Current.siteURL = { "http://localhost:8080" }
            return node().render(indentedBy: .spaces(2))
        }
    }
}

#if os(macOS)
extension Snapshotting where Value == () -> HTML, Format == NSImage {
    public static func image(precision: Float = 1, size: CGSize? = nil, rootDir: URL) -> Snapshotting {
        Current.siteURL = { String(rootDir.absoluteString.dropLast()) }
        return image(precision: precision, size: size, baseURL: rootDir)
    }

    public static func image(precision: Float = 1, size: CGSize? = nil, baseURL: URL) -> Snapshotting {
        Snapshotting<NSView, NSImage>.image(precision: precision, size: size).pullback { node in
            let html = node().render()
            let webView = WKWebView()
            
            let htmlURL = baseURL.appendingPathComponent(TempWebRoot.fileName)
            
            // Save HTML file at root of public directory
            do {
                try html.write(to: htmlURL, atomically: true, encoding: .utf8)
            } catch {
                fatalError("Snapshotting: 💥 Failed to write index.html: \(error)")
            }
            
            // Load the HTML file into the web view with access to public directory
            webView.loadFileURL(htmlURL, allowingReadAccessTo: baseURL)
            
            return webView
        }
    }
}
#endif


extension AppError: Equatable {
    public static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
            case let (.envVariableNotSet(v1), .envVariableNotSet(v2)):
                return v1 == v2
            case let (.genericError(id1, v1), .genericError(id2, v2)):
                return (id1, v1) == (id2, v2)
            case let (.invalidPackageCachePath(id1, v1), .invalidPackageCachePath(id2, v2)):
                return (id1, v1) == (id2, v2)
            case let (.invalidPackageUrl(id1, v1), .invalidPackageUrl(id2, v2)):
                return (id1, v1) == (id2, v2)
            case let (.invalidRevision(id1, v1), .invalidRevision(id2, v2)):
                return (id1, v1) == (id2, v2)
            case let (.metadataRequestFailed(id1, s1, u1), .metadataRequestFailed(id2, s2, u2)):
                return (id1, s1.code, u1.description) == (id2, s2.code, u2.description)
            default:
                return false
        }
    }
}
