import Plot


class HomeIndex: PublicPage {

    override func main() -> Node<HTML.BodyContext> {
        .group(
            .section(
                .class("search"),
                .div(
                    .class("inner"),
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
                )
            ),
            .main(
                .div(.class("inner"),
                     content()
                )
            )
        )
    }

    override func content() -> Node<HTML.BodyContext> {
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
