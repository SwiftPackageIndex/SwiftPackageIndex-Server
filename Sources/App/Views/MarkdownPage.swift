import Foundation
import Plot
import Ink

class MarkdownPage: PublicPage {

    let pathToMarkdownFile: String

    init(_ markdownFilename: String) {
        assert(markdownFilename.split(separator: "/").count < 2, "Filename should not include path separators.")

        pathToMarkdownFile = Current.fileManager.workingDirectory()
            .appending("Resources/Markdown/")
            .appending(markdownFilename)
    }

    override func bodyClass() -> String? {
        "markdown"
    }

    override func content() -> Node<HTML.BodyContext> {
        do {
            let markdown = try String(contentsOfFile: pathToMarkdownFile)
            let rawHTML = MarkdownParser().html(from: markdown)
            return .raw(rawHTML)
        } catch {
            return .p("Markdown file not found!")
        }
    }

}
