import Plot


enum PackageShow {

    class View: PublicPage {

        let model: Model

        init(_ model: Model) {
            self.model = model
        }

        override func pageTitle() -> String? {
            model.title
        }

        override func bodyClass() -> String? {
            "package"
        }

        override func content() -> Node<HTML.BodyContext> {
            .group(
                .div(
                    .class("split"),
                    .div(
                        .h2(.text(model.title)),
                        .element(named: "small", nodes: [ // TODO: Fix after Plot update
                            .a(
                                .href(model.url),
                                .text(model.url)
                            )
                        ])
                    ),
                    .div(
                        .class("license"),
                        .attribute(named: "title", value: model.license.fullName), // TODO: Fix after Plot update
                        .i(.class("icon osi")),
                        .text(model.license.shortName)
                    )
                ),
                .hr(),
                .p(
                    .class("description"),
                    .text(model.summary)
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
                .section(
                    .class("language_platforms"),
                    .h3("Language and Platforms"),
                    .unwrap(model.languagesAndPlatformsClause(), { .ul(.group($0)) },
                            else: .p(
                                .text("The manifest for this package doesn't include metadata on which versions of Swift, and which platforms it supports – Are you the package author? "),
                                .a(
                                    .href(SiteURL.faq.relativeURL(anchor: "language-and-platforms")),
                                    .text("Learn how to fix this")
                                ),
                                .text(".")
                        )
                    )
                )
            )
        }
    }
}
