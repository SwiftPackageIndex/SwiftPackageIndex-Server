import Plot


enum HomeIndex {

    class View: PublicPage {

        let model: Model

        init(_ model: Model) {
            self.model = model
        }

        override func noScript() -> Node<HTML.BodyContext> {
            .noscript(
                .i(
                    .class("icon warning")
                ),
                .p("The search function of this site requires JavaScript.")
            )
        }

        override func preMain() -> Node<HTML.BodyContext> {
            .section(
                .class("search"),
                .div(
                    .class("inner"),
                    .h3("The place to find Swift packages."),
                    .form(
                        .textarea(
                            .id("query"),
                            .attribute(named: "placeholder", value: "Search"), // TODO: Fix after Plot update
                            .attribute(named: "spellcheck", value: "false"), // TODO: Fix after Plot update
                            .attribute(named: "data-gramm", value: "false"),
                            .autofocus(true),
                            .rows(1)
                        ),
                        .div(
                            .id("results"),
                            .attribute(named: "hidden", value: "true") // TODO: Fix after Plot update
                        )
                    )
                )
            )
        }

        override func content() -> Node<HTML.BodyContext> {
            .div(
                .class("recent"),
                .section(
                    .class("recent_packages"),
                    .h3("Recent Packages"),
                    .ul(model.recentPackagesSection())
                ),
                .section(
                    .class("recent_releases"),
                    .h3("Recent Releases"),
                    .ul(model.recentReleasesSection())
                )
            )
        }

        override func navItems() -> [Node<HTML.ListContext>] {
            // The default navigation menu, without search.
            [
                .li(
                    .a(
                        .href("https://github.com/daveverwer/SwiftPMLibrary"),
                        "Add a Package"
                    )
                ),
                .li(
                    .a(
                        .href(SiteURL.faq.relativeURL()),
                        "FAQ"
                    )
                )
            ]
        }

    }

}
