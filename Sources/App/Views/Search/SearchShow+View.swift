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
                    .div(
                        .class("inner"),
                        .searchForm(query: model.query)
                    )
                ),
                .if(model.query.count > 0, resultsSection())
            )
        }

        override func navMenuItems() -> [NavMenuItem] {
            [.sponsorCTA, .addPackage, .blog, .faq]
        }

        func resultsSection() -> Node<HTML.BodyContext> {
            .section(
                .div(
                    .class("inner"),
                    .p(
                        .text("Results for "),
                        .text("&ldquo;"),
                        .strong(.text(model.query)),
                        .text("&rdquo;&hellip;")
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
            )
        }
    }
}
