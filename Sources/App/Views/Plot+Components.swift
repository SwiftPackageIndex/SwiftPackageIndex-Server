import Plot

extension Node where Context == HTML.BodyContext {
    static func searchForm(query: String = "") -> Self {
        .form(
            .action(SiteURL.search.relativeURL()),
            .searchField(query: query),
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
    static func searchField(query: String = "") -> Self {
        .input(
            .id("query"),
            .name("query"),
            .type(.search),
            .attribute(named: "placeholder", value: "Search"), // TODO: Fix after Plot update
            .attribute(named: "spellcheck", value: "false"), // TODO: Fix after Plot update
            .attribute(named: "data-gramm", value: "false"),
            .value(query)
        )
    }
}
