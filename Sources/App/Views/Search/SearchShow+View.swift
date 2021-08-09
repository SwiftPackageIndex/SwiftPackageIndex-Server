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
                        .if(model.response.results.count > 0, .text("Results for "), else: .text("No results for ")),
                        .text("&ldquo;"),
                        .strong(.text(model.query)),
                        .text("&rdquo;"),
                        .if(model.response.results.count > 0, .text("&hellip;"), else: .text("."))
                    ),
                    .ul(
                        .id("package_list"),
                        // Let the JavaScript know that keyboard navigation on this package list should
                        // also include navigation into and out of the query field.
                        .data(named: "focus-query-field", value: String(true)),
                        .group(
                            model.response.results.map { result -> Node<HTML.ListContext> in
                                .li(
                                    .a(
                                        .href(result.link),
                                        .h4(.text(result.title)),
                                        .unwrap(result.summary) { .p(.text($0)) },
                                        .small(
                                            .text(result.footer)
                                        )
                                    )
                                )
                            }
                        )
                    ),
                    .ul(
                        .class("pagination"),
                        .if(model.page > 1, .previousPage(model: model)),
                        .if(model.response.hasMoreResults, .nextPage(model: model))
                    )
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
