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
                    .ul(
                        .class("search_pagination"),
                        .if(model.page > 1, .previousSearchPage(model: model)),
                        .if(model.result.hasMoreResults, .nextSearchPage(model: model))
                    )
                )
            )
        }
    }
}

fileprivate extension Node where Context == HTML.ListContext {
    static func previousSearchPage(model: SearchShow.Model) -> Node<HTML.ListContext> {
        let parameters = [
            QueryParameter(key: "query", value: model.query),
            QueryParameter(key: "page", value: model.page - 1)
        ]
        return .li(
            .class("previous"),
            .a(
                .href(SiteURL.search.relativeURL(parameters: parameters)),
                "Previous Page"
            )
        )
    }

    static func nextSearchPage(model: SearchShow.Model) -> Node<HTML.ListContext> {
        let parameters = [
            QueryParameter(key: "query", value: model.query),
            QueryParameter(key: "page", value: model.page + 1)
        ]
        return .li(
            .class("next"),
            .a(
                .href(SiteURL.search.relativeURL(parameters: parameters)),
                "Next Page"
            )
        )
    }
}
