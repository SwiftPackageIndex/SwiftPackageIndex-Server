import Plot


class HomeIndex: PublicPage {

    override func content() -> Node<HTML.BodyContext> {
        .p("Home page")
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
