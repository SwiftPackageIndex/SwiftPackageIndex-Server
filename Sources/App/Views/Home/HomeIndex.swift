import Plot


class HomeIndex: PublicPage {

    override func content() -> Node<HTML.BodyContext> {
        .group(
            .div(
                .class("search"),
                .p(
                    "The place to find Swift packages."
                ),
                .form(
                    .input(
                        .type(.text),
                        .attribute(named: "spellcheck", value: "false"), // TODO: Fix after Plot update
                        .placeholder("Search")
                    )
                )
            ),
            .div(
                .class("split"),
                .section(
                    .class("recent_packages"),
                    .ul(
                        .li(
                            "Package",
                            .element(named: "small", text: "2 hours ago.") // TODO: Fix after Plot update
                        ),
                        .li(
                            "Package",
                            .element(named: "small", text: "2 hours ago.") // TODO: Fix after Plot update
                        ),
                        .li(
                            "Package",
                            .element(named: "small", text: "2 hours ago.") // TODO: Fix after Plot update
                        ),
                        .li(
                            "Package",
                            .element(named: "small", text: "2 hours ago.") // TODO: Fix after Plot update
                        ),
                        .li(
                            "Package",
                            .element(named: "small", text: "2 hours ago.") // TODO: Fix after Plot update
                        ),
                        .li(
                            "Package",
                            .element(named: "small", text: "2 hours ago.") // TODO: Fix after Plot update
                        ),
                        .li(
                            "Package",
                            .element(named: "small", text: "2 hours ago.") // TODO: Fix after Plot update
                        )
                    )
                ),
                .section(
                    .class("recent_releases"),
                    .ul(
                        .li(
                            "Package",
                            .element(named: "small", text: "2 hours ago.") // TODO: Fix after Plot update
                        ),
                        .li(
                            "Package",
                            .element(named: "small", text: "2 hours ago.") // TODO: Fix after Plot update
                        ),
                        .li(
                            "Package",
                            .element(named: "small", text: "2 hours ago.") // TODO: Fix after Plot update
                        ),
                        .li(
                            "Package",
                            .element(named: "small", text: "2 hours ago.") // TODO: Fix after Plot update
                        ),
                        .li(
                            "Package",
                            .element(named: "small", text: "2 hours ago.") // TODO: Fix after Plot update
                        ),
                        .li(
                            "Package",
                            .element(named: "small", text: "2 hours ago.") // TODO: Fix after Plot update
                        ),
                        .li(
                            "Package",
                            .element(named: "small", text: "2 hours ago.") // TODO: Fix after Plot update
                        )
                    )
                )
            )
        )
    }

    override func navItems() -> [Node<HTML.ListContext>] {
        // The default navigation menu, without search.
        [
            .li(
                .a(
                    .href("#"),
                    "Add a Package"
                )
            ),
            .li(
                .a(
                    .href("#"),
                    "About"
                )
            )
        ]
    }

}
