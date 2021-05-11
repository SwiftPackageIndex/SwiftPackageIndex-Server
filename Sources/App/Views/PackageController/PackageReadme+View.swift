import Vapor
import Plot
import SwiftSoup

enum PackageReadme {
    
    class View: TurboFrame {
        
        let model: Model

        init(model: Model) {
            self.model = model
            super.init()
        }

        override func frameIdentifier() -> String {
            "readme"
        }

        override func frameContent() -> Plot.Node<HTML.BodyContext> {
            guard let readme = model.readme
            else { return .empty }

            do {
                let htmlDocument = try SwiftSoup.parse(readme)
                let cssQuery = try htmlDocument.select("#readme article")
                guard let articleElement = cssQuery.first()
                else { return .empty }

                return .group(
                    .hr(),
                    .article(
                        .class("readme"),
                        .attribute(named: "data-readme-base-url", value: model.readmeBaseUrl),
                        .raw(try articleElement.html())
                    )
                )
            } catch {
                return .empty
            }
        }
    }
    
}
