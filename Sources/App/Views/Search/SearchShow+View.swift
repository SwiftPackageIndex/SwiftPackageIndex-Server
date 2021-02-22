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
                .h2(.text("Results for \(model.query)")),
                .ul(
                    .class("list"),
                    .group(
                        model.result.results.map { result -> Node<HTML.ListContext> in
                            .li(
                                .a(
                                    .href(result.packageURL ?? "-"),
                                    .h4(.text(result.packageName ?? "-")),
                                    .p(.text(result.summary ?? "-"))
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
