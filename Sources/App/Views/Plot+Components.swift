import Plot

extension Node where Context == HTML.BodyContext {
    static func searchForm(query: String = "", autofocus: Bool = true) -> Self {
        .form(
            .action(SiteURL.search.relativeURL()),
            .searchField(query: query, autofocus: autofocus),
            .button(
                .attribute(named: "type", value: "submit"),
                .div(
                    .attribute(named: "title", value: "Search")
                )
            )
        )
    }
}

extension Node where Context == HTML.FormContext {
    static func searchField(query: String = "", autofocus: Bool = true) -> Self {
        // Yes, this if/else is awful, but Plot does not have a way to do conditional attributes.
        .if(autofocus,
            .input(
                .id("query"),
                .name("query"),
                .type(.search),
                .attribute(named: "placeholder", value: "Search"),
                .attribute(named: "spellcheck", value: "false"),
                .attribute(named: "autofocus", value: "true"),
                .attribute(named: "data-gramm", value: "false"),
                .value(query)
            ), else: .input(
                .id("query"),
                .name("query"),
                .type(.search),
                .attribute(named: "placeholder", value: "Search"),
                .attribute(named: "spellcheck", value: "false"),
                .attribute(named: "data-gramm", value: "false"),
                .value(query)
            )
        )
    }
}
