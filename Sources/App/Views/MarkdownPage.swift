// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
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

import Foundation

import Dependencies
import Ink
import Plot


class MarkdownPage: PublicPage {

    enum Metadata: String {
        case pageTitle = "page-title"
        case description
    }

    let metadata: [String: String]
    let html: String?

    init(path: String, _ markdownFilename: String) {
        @Dependency(\.fileManager) var fileManager
        let pathToMarkdownFile = fileManager.workingDirectory()
            .appending("Resources/Markdown/")
            .appending(markdownFilename)

        let markdown = try? String(contentsOfFile: pathToMarkdownFile, encoding: .utf8)
        let result = markdown.map(MarkdownParser().parse)
        metadata = result?.metadata ?? [:]
        html = result?.html

        super.init(path: path)
    }

    init(path: String, markdown: String) {
        let result = MarkdownParser().parse(markdown)
        metadata = result.metadata
        html = result.html

        super.init(path: path)
    }

    init(path: String, html: String) {
        self.metadata = [:]
        self.html = html
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

    override func breadcrumbs() -> [Breadcrumb] {
        guard let pageTitle = metadata[Metadata.pageTitle] else { return [] }

        return [
            Breadcrumb(title: "Home", url: SiteURL.home.relativeURL()),
            Breadcrumb(title: pageTitle),
        ]
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
