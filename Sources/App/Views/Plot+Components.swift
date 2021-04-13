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

    static func spinner() -> Self {
        .div(
            .class("spinner"),
            .div(.class("rect1")),
            .div(.class("rect2")),
            .div(.class("rect3")),
            .div(.class("rect4")),
            .div(.class("rect5"))
        )
    }
}

extension Node where Context == HTML.FormContext {
    static func searchField(query: String = "", autofocus: Bool = true) -> Self {
        .input(
            .id("query"),
            .name("query"),
            .type(.search),
            .attribute(named: "placeholder", value: "Search"),
            .attribute(named: "spellcheck", value: "false"),
            .attribute(named: "autocomplete", value: "off"),
            .attribute(named: "data-gramm", value: "false"),
            .attribute(named: "data-autofocus", value: String(describing: autofocus)),
            .value(query)
        )
    }
}
