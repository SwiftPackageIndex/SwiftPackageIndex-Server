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
        .input(
            autofocus: autofocus,
            .id("query"),
            .name("query"),
            .type(.search),
            .attribute(named: "placeholder", value: "Search"),
            .attribute(named: "spellcheck", value: "false"),
            .attribute(named: "data-gramm", value: "false"),
            .value(query)
        )
    }
}
