import Foundation
import Plot
import Ink


class MarkdownPage: PublicPage {

    enum Metadata: String {
        case pageTitle = "page-title"
    }

    let metadata: [String: String]
    let html: String?

    init(_ markdownFilename: String) {
        assert(markdownFilename.split(separator: "/").count < 2, "Filename should not include path separators.")

        let pathToMarkdownFile = Current.fileManager.workingDirectory()
            .appending("Resources/Markdown/")
            .appending(markdownFilename)

        let markdown = try? String(contentsOfFile: pathToMarkdownFile)
        let result = markdown.map(MarkdownParser().parse)
        metadata = result?.metadata ?? [:]
        html = result?.html
    }

    override func pageTitle() -> String? {
        metadata[Metadata.pageTitle]
    }

    override func bodyClass() -> String? {
        "markdown"
    }

    override func content() -> Node<HTML.BodyContext> {
        guard let html = html else {
            return .p("Markdown file not found!")
        }
        return .raw(html)
    }

}


private extension Dictionary where Key == String, Value == String {
    subscript(_ key: MarkdownPage.Metadata) -> String? {
        self[key.rawValue]
    }
}
