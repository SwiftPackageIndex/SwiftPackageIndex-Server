import Foundation
import Plot
import Ink

class MarkdownPage: PublicPage {

    let markdownFile: String

    init(_ pathToMarkdown: String) {
        markdownFile = Current.fileManager.workingDirectory()
            .appending("Resources/Markdown/")
            .appending(pathToMarkdown)
    }

    override func content() -> Node<HTML.BodyContext> {
        do {
            let markdown = try String(contentsOfFile: markdownFile)
            let rawHTML = MarkdownParser().html(from: markdown)
            return .raw(rawHTML)
        } catch {
            return .p("Markdown file not found!")
        }
    }

}
