// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
        Snapshotting<() -> HTML, String>.html.pullback { node in
            { HTML(.body(node())) }
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
        Snapshotting<() -> HTML, NSImage>.image(precision: precision,
                                                size: size,
                                                baseURL: baseURL).pullback { node in
            { HTML(.body(node())) }
        }
    }
}
#endif

