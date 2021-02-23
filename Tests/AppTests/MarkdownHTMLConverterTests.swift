@testable import App

import SnapshotTesting
import Vapor
import XCTest
import Plot


class MarkdownHTMLConverterTests: WebpageSnapshotTestCase {
    
    class MarkdownConverterPage: PublicPage {
        let markdown: String
        
        init(markdown: String) {
            self.markdown = markdown
            super.init(path: "")
        }
        
        override func content() -> Node<HTML.BodyContext> {
            do {
                let html = try MarkdownHTMLConverter.html(from: markdown)
                return .article(
                    .class("readme"),
                    .raw(html)
                )
            } catch {
                return .h1("Failed to convert: \(error.localizedDescription)")
            }
        }
    }

    func test_MarkdownConverter() throws {
        let data = try XCTUnwrap(try loadData(for: "markdown-test.md"))
        let markdown = try XCTUnwrap(String(data: data, encoding: .utf8))
        let page = MarkdownConverterPage(markdown: markdown)
        
        assertSnapshot(matching: page.content().render(indentedBy: .spaces(4)), as: .lines)
        
        #if os(macOS)
        let height: CGFloat = 3000
        let configs: [(name: String, size: CGSize)] = [
            ("desktop", CGSize(width: CGSize.desktop.width, height: height)),
            ("mobile", CGSize(width: CGSize.mobile.width, height: height))
        ]
        
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: { page.document() },
                               as: .image(precision: defaultPrecision,
                                          size: $0.size,
                                          baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }

}
