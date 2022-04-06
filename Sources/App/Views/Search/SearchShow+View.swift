// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Plot


extension SearchShow {

    class View: PublicPage {

        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }

        override func pageTitle() -> String? {
            if model.query.count > 0 && model.term.isEmpty == false {
                return "Search Results for &ldquo;\(model.term)&rdquo;"
            } else {
                return "Search Results"
            }
        }

        override func breadcrumbs() -> [Breadcrumb] {
            [
                Breadcrumb(title: "Home", url: SiteURL.home.relativeURL()),
                Breadcrumb(title: "Search Results for &ldquo;\(model.term)&rdquo;")
            ]
        }

        override func content() -> Node<HTML.BodyContext> {
            .group(
                .section(
                    .class("search"),
                    .searchForm(query: model.query),
                    .div(
                        .class("filter_suggestions"),
                        .text("Add filters to narrow search results. "),
                        .span(
                            .class("learn_more"),
                            .a(
                                .href(SiteURL.faq.relativeURL(anchor: "search-filters")),
                                .text("Learn more")
                            ),
                            .text(".")
                        )
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
                .class("search_results"),
                .if(model.term.isEmpty == false, .p(
                    .text("Results for &ldquo;"),
                    .strong(.text(model.term)),
                    .text("&rdquo;&hellip;")
                )),
                .if(model.authorResults.count > 0 || model.keywordResults.count > 0, .div(
                    .class("two_column mobile_reversed"),
                    packageResultsSection(),
                    .div(
                        authorResultsSection(),
                        keywordResultsSection()
                    )
                ), else: packageResultsSection())
            )
        }

        func packageResultsSection() -> Node<HTML.BodyContext> {
            return .section(
                .class("package_results"),
                .h4("Matching packages\(model.filters.isEmpty ? "" : " where&hellip;")"),
                .if(model.filters.isEmpty == false,
                    .ul(
                        .class("filter_list"),
                        .group(
                            model.filters.map {
                                .li(
                                    .span(
                                        .class("filter-key"),
                                        .text($0.key.description)
                                    ),
                                    .text(" "),
                                    .span(
                                        .class("filter-comparison"),
                                        .text($0.operator)
                                    ),
                                    .text(" "),
                                    .span(
                                        .class("filter-value"),
                                        .text($0.value)
                                    )
                                )
                            }
                        )
                    )
                ),
                .if(model.packageResults.isEmpty, .p(
                    .text("No packages found.")
                )),
                .ul(
                    .id("package_list"),
                    // Let the JavaScript know that keyboard navigation on this package list should
                    // also include navigation into and out of the query field.
                    .data(named: "focus-query-field", value: String(true)),
                    .group(
                        model.packageResults.map { .packageListItem(linkUrl: $0.packageURL, packageName: $0.packageName ?? $0.repositoryName, summary: $0.summary, matchingKeywords: model.matchingKeywords(packageKeywords: $0.keywords), repositoryOwner: $0.repositoryOwner, repositoryName: $0.repositoryName, stars: $0.stars, lastActivityAt: $0.lastActivityAt) }
                    )
                ),
                .ul(
                    .class("pagination"),
                    .if(model.page > 1, .previousPage(model: model)),
                    .if(model.response.hasMoreResults, .nextPage(model: model))
                )
            )
        }

        func authorResultsSection() -> Node<HTML.BodyContext> {
            guard model.authorResults.count > 0
            else { return .empty }

            return .section(
                .class("author_results"),
                .h4("Matching authors"),
                .spiOverflowingList(overflowMessage: "Show more authors…", overflowHeight: 129,
                                    .forEach(model.authorResults) { authorResultListItem($0) })
            )
        }

        private func authorResultListItem(_ author: Search.AuthorResult) -> Node<HTML.ListContext> {
            .li(
                .a(
                    .href(SiteURL.author(.value(author.name)).relativeURL()),
                    .text(author.name)
                )
            )
        }

        func keywordResultsSection() -> Node<HTML.BodyContext> {
            guard model.keywordResults.count > 0
            else { return .empty }

            return .section(
                .class("keyword_results"),
                .h4("Matching keywords"),
                .spiOverflowingList(overflowMessage: "Show more keywords…", overflowHeight: 260, listClass: "keywords",
                                    .forEach(model.keywordResults) { keywordResultListItem($0) })
            )
        }

        private func keywordResultListItem(_ keyword: Search.KeywordResult) -> Node<HTML.ListContext> {
            .li(
                .a(
                    .href(SiteURL.keywords(.value(keyword.keyword)).relativeURL()),
                    .text(keyword.keyword)
                )
            )
        }
    }
}


fileprivate extension Node where Context == HTML.ListContext {
    static func previousPage(model: SearchShow.Model) -> Node<HTML.ListContext> {
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

    static func nextPage(model: SearchShow.Model) -> Node<HTML.ListContext> {
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
