import Plot


extension SearchShow {

    class View: PublicPage {

        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }

        override func content() -> Node<HTML.BodyContext> {
            .group(
                .section(
                    .class("search"),
                    .form(
                        .action(SiteURL.search.relativeURL()),
                        .input(
                            .id("query"),
                            .name("query"),
                            .type(.search),
                            .attribute(named: "placeholder", value: "Search"), // TODO: Fix after Plot update
                            .attribute(named: "spellcheck", value: "false"), // TODO: Fix after Plot update
                            .attribute(named: "data-gramm", value: "false"),
                            .value(model.query)
                        ),
                        .submit(text: "Search")
                    )
                ),
                .p(
                    .text("Results for "),
                    .strong(.text(model.query))
                ),
                .ul(
                    .class("package_list"),
                    .group(
                        model.result.results.map { result -> Node<HTML.ListContext> in
                            .li(
                                .a(
                                    // TODO: The view feels like the wrong place to have optional data for these things. Move to view model?
                                    .href(result.packageURL ?? "-"),
                                    .h4(.text(result.packageName ?? "-")),
                                    .p(.text(result.summary ?? "-")),
                                    .small(
                                        .text(result.repositoryOwner ?? "-"),
                                        .text("/"),
                                        .text(result.repositoryName ?? "-")
                                    )
                                )
                            )
                        }
                    )
                ),
                .if(model.page > 1,
                    .a(.href(SiteURL.search
                                .absoluteURL(parameters: ["page": "\(model.page - 1)",
                                                          "query": model.query])),
                       "previous")
                ),
                .if(model.page > 1 && model.result.hasMoreResults,
                    " | "),
                .if(model.result.hasMoreResults,
                    .a(.href(SiteURL.search
                                .absoluteURL(parameters: ["page": "\(model.page + 1)",
                                                          "query": model.query])),
                       "next")
                )
            )
        }
    }

}
