@testable import App

import Plot
import SnapshotTesting

#if canImport(WebKit)
import WebKit
#endif


extension Snapshotting where Value == () -> HTML, Format == String {
    public static var html: Snapshotting {
        Snapshotting<String, String>.lines.pullback { node in
            Current.siteURL = { "http://localhost:8080" }
            return node().render(indentedBy: .spaces(2))
        }
    }
}

extension Snapshotting where Value == () -> Node<HTML.BodyContext>, Format == String {
    public static var html: Snapshotting {
        Snapshotting<String, String>.lines.pullback { node in
            Current.siteURL = { "http://localhost:8080" }
            return node().render(indentedBy: .spaces(2))
        }
    }
}

#if os(macOS)
extension Snapshotting where Value == () -> HTML, Format == NSImage {
    public static func image(precision: Float = 1, size: CGSize? = nil, baseURL: URL) -> Snapshotting {
        // Set siteURL to the webroot folder ...
        Current.siteURL = { baseURL.absoluteString }
        // ... and ensure we use absolute paths for image + stylesheet urls
        SiteURL.relativeURL = { path in
            switch path {
                case _ where path.hasPrefix("images/"):
                    return Current.siteURL() + SiteURL._relativeURL(path)
                case _ where path.hasSuffix(".css") || path.hasSuffix(".js"):
                    return Current.siteURL() + SiteURL._relativeURL(path)
                default:
                    return SiteURL._relativeURL(path)
            }
        }

        // Force light mode
        NSApplication.shared.appearance = NSAppearance(named: .aqua)

        return Snapshotting<NSView, NSImage>.image(precision: precision, size: size).pullback { node in
            // ... and reset our relativeURL override from above so we don't break other tests
            defer { SiteURL.relativeURL = SiteURL._relativeURL }

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

extension Snapshotting where Value == () -> Node<HTML.BodyContext>, Format == NSImage {
    public static func image(precision: Float = 1, size: CGSize? = nil, baseURL: URL) -> Snapshotting {
        // Set siteURL to the webroot folder ...
        Current.siteURL = { baseURL.absoluteString }
        // ... and ensure we use absolute paths for image + stylesheet urls
        SiteURL.relativeURL = { path in
            switch path {
                case _ where path.hasPrefix("images/"):
                    return Current.siteURL() + SiteURL._relativeURL(path)
                case _ where path.hasSuffix(".css") || path.hasSuffix(".js"):
                    return Current.siteURL() + SiteURL._relativeURL(path)
                default:
                    return SiteURL._relativeURL(path)
            }
        }

        // Force light mode
        NSApplication.shared.appearance = NSAppearance(named: .aqua)

        return Snapshotting<NSView, NSImage>.image(precision: precision, size: size).pullback { node in
            // ... and reset our relativeURL override from above so we don't break other tests
            defer { SiteURL.relativeURL = SiteURL._relativeURL }

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

