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
                        .li(
                            .class("icon author"),
                            .group(model.authorsClause())
                        )
                        ,
                        .li(
                            .class("icon history"),
                            .group(model.historyClause())
                        ),
                        .li(
                            .class("icon activity"),
                            .group(model.activityClause())
                        ),
                        .li(
                            .class("icon products"),
                            .group(model.productsClause())
                        )
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
                    .ul(
                        .group(model.languagesAndPlatformsClause())
                    )
                )
            )
        }
    }
}
