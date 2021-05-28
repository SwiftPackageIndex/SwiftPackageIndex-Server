import Plot


extension SearchShow {

    class View: PublicPage {

        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }

        override func pageTitle() -> String? {
            if model.query.count > 0 {
                return "Search Results for &ldquo;\(model.query)&rdquo;"
            } else {
                return "Search"
            }
        }

        override func content() -> Node<HTML.BodyContext> {
            .group(
                .section(
                    .class("search"),
                    .searchForm(query: model.query)
                ),
                .if(model.query.count > 0, resultsSection())
            )
        }

        override func navMenuItems() -> [NavMenuItem] {
            [.sponsorCTA, .addPackage, .blog, .faq]
        }

        func resultsSection() -> Node<HTML.BodyContext> {
            .group(
                .section(
                    .class("results"),
                    .p(
                        .if(model.result.results.count > 0, .text("Results for "), else: .text("No packages matched ")),
                        .text("&ldquo;"),
                        .strong(.text(model.query)),
                        .text("&rdquo;"),
                        .if(model.result.results.count > 0, .text("&hellip;"), else: .text("."))
                    ),
                    .ul(
                        .id("package_list"),
                        // Let the JavaScript know that keyboard navigation on this package list should
                        // also include navigation into and out of the query field.
                        .data(named: "focus-query-field", value: String(true)),
                        .group(
                            model.result.results.map { result -> Node<HTML.ListContext> in
                                .li(
                                    .a(
                                        .href(result.packageURL),
                                        .h4(.text(result.packageName)),
                                        .unwrap(result.summary) { .p(.text($0)) },
                                        .small(
                                            .text(result.repositoryOwner),
                                            .text("/"),
                                            .text(result.repositoryName)
                                        )
                                    )
                                )
                            }
                        )
                    ),
                    .ul(
                        .class("pagination"),
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
