import Ink
import Vapor
import Plot

enum PackageShow {
    
    class View: PublicPage {
        
        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }
        
        override func pageTitle() -> String? {
            model.title
        }
        
        override func pageDescription() -> String? {
            var description = "\(model.title) on the Swift Package Index"
            if let summary = model.summary {
                description += " – \(summary)"
            }
            return description
        }
        
        override func bodyClass() -> String? {
            "package"
        }

        override func bodyComments() -> Node<HTML.BodyContext> {
            .group(
                .comment(model.packageId.uuidString),
                .comment(model.score.map(String.init) ?? "unknown")
            )
        }
        
        override func content() -> Node<HTML.BodyContext> {
            .group(
                .div(
                    .class("split"),
                    .div(
                        .h2(.text(model.title)),
                        .element(named: "small", nodes: [ // TODO: Fix after Plot update
                            .a(
                                .id("package_url"),
                                .href(model.url),
                                .text(model.url)
                            )
                        ]),
                        arenaButton()
                    ),
                    licenseMetadata()
                ),
                .hr(),
                .p(
                    .class("description"),
                    .unwrap(model.summary) { summary in
                        .text(summary.replaceShorthandEmojis())
                    }
                ),
                .section(
                    .class("metadata"),
                    .ul(
                        .unwrap(model.authorsClause()) {
                            .li(.class("icon author"), $0)
                        },
                        .unwrap(model.historyClause()) {
                            .li(.class("icon history"), $0)
                        },
                        .unwrap(model.activityClause()) {
                            .li(.class("icon activity"), $0)
                        },
                        .unwrap(model.productsClause()) {
                            .li(.class("icon products"), $0)
                        },
                        .unwrap(model.starsClause()) {
                            .li(.class("icon stars"), $0)
                        }
                    )
                ),
                .element(named: "hr", nodes:[ // TODO: Fix after Plot update
                    .attribute(named: "class", value: "short")
                ]),
                .section(
                    .class("releases"),
                    .ul(
                        .li(.group(model.stableReleaseClause())),
                        .li(.group(model.betaReleaseClause())),
                        .li(.group(model.latestReleaseClause()))
                    )
                ),
                .group(
                    model.swiftVersionCompatibilitySection(),
                    model.platformCompatibilitySection()
                ),
                readmeSection()
            )
        }
        
        func licenseLozenge() -> Node<HTML.BodyContext> {
            switch model.license.licenseKind {
                case .compatibleWithAppStore:
                    return .div(
                        .class("lozenge green"),
                        .attribute(named: "title", value: model.license.fullName), // TODO: Fix after Plot update
                        .i(.class("icon osi")),
                        .text(model.license.shortName)
                    )
                case .other:
                    return .div(
                        .class("lozenge \(model.license.licenseKind.cssClass)"),
                        .attribute(named: "title", value: model.license.fullName), // TODO: Fix after Plot update
                        .i(.class("icon warning")),
                        .text(model.license.shortName)
                    )
                case .none,
                     .incompatibleWithAppStore:
                    return .div(
                        .class("lozenge \(model.license.licenseKind.cssClass)"),
                        .attribute(named: "title", value: model.license.fullName), // TODO: Fix after Plot update
                        .i(.class("icon warning")),
                        .text(model.license.shortName)
                    )
            }
        }

        func licenseMetadata() -> Node<HTML.BodyContext> {
            return .div(
                .class("license"),
                .a(
                    .href(SiteURL.faq.relativeURL(anchor: "licenses")),
                    .i(.class("icon question"))
                ),
                .unwrap(model.licenseUrl, { licenseUrl in
                    .a(
                        href: licenseUrl,
                        licenseLozenge()
                    )
                }, else: licenseLozenge())
            )
        }

        func arenaButton() -> Node<HTML.BodyContext> {
            let environment = (try? Environment.detect()) ?? .development
            return .if(environment != .production,
                       .a(.href("slide://open?dependencies=\(model.repositoryOwner)/\(model.repositoryName)"),
                          "🏟")
            )
        }

        func readmeSection() -> Node<HTML.BodyContext> {
            guard let readme = model.readme,
                  let html = try? MarkdownHTMLConverter.html(from: readme)
            else { return .empty }

            return .group(
                .hr(),
                .article(
                    .class("readme"),
                    .attribute(named: "data-readme-base-url", value: model.readmeBaseUrl),
                    .raw(html)
                )
            )
        }
    }
}


private extension License.Kind {
    var cssClass: String {
        switch self {
            case .none: return "red"
            case .incompatibleWithAppStore, .other: return "orange"
            case .compatibleWithAppStore: return "green"
        }
    }
}
