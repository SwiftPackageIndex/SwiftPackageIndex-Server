import Foundation
import Plot
import Ink


class MarkdownPage: PublicPage {
    
    enum Metadata: String {
        case pageTitle = "page-title"
        case description
    }
    
    let metadata: [String: String]
    let html: String?
    
    init(path: String, _ markdownFilename: String) {
        let pathToMarkdownFile = Current.fileManager.workingDirectory()
            .appending("Resources/Markdown/")
            .appending(markdownFilename)
        
        let markdown = try? String(contentsOfFile: pathToMarkdownFile)
        let result = markdown.map(MarkdownParser().parse)
        metadata = result?.metadata ?? [:]
        html = result?.html
        
        super.init(path: path)
    }
    
    override func pageTitle() -> String? {
        metadata[Metadata.pageTitle]
    }
    
    override func pageDescription() -> String? {
        metadata[Metadata.description]
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
