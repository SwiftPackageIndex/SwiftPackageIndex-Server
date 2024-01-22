// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
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

import Foundation
import Plot

extension BlogShow {

    class View: PublicPage {
        
        let model: BlogIndex.Model.PostSummary

        init(path: String, model: BlogIndex.Model.PostSummary) {
            self.model = model
            super.init(path: path)
        }
        
        override func pageTitle() -> String? {
            return "\(model.title) on the Swift Package Index Blog"
        }

        override func bodyClass() -> String? {
            "blog"
        }

        override func breadcrumbs() -> [Breadcrumb] {
            [
                Breadcrumb(title: "Home", url: SiteURL.home.relativeURL()),
                Breadcrumb(title: "Blog", url: SiteURL.blogIndex.relativeURL()),
                Breadcrumb(title: model.title)
            ]
        }
        
        override func content() -> Node<HTML.BodyContext> {
            .group(
                .h2(
                    .text(model.title)
                ),
                .if(model.published, .small(
                    "Published on ",
                    .text(DateFormatter.longDateFormatter.string(from: summary.publishedAt))
                ), else: .small(
                    .strong("DRAFT POST")
                )),
                .ul(
                    .class("blog-posts"),
                    .group(
                        model.summaries.map({ summary -> Node<HTML.ListContext> in
                                .li(
                                    .a(
                                        .href(summary.slug),
                                        .h3(.text(summary.title)),
                                        .p(
                                            .text(summary.summary)
                                        ),
                                        .div(
                                            .class("read-full-post"),
                                            .if(summary.published, .small(
                                                "Published on ",
                                                .text(DateFormatter.longDateFormatter.string(from: summary.publishedAt))
                                            ), else: .small(
                                                .strong("DRAFT POST")
                                            )),
                                            .p(
                                                .text(summary.published ? "Read full post" : "Read draft post" ),
                                                .text("&hellip;")
                                            )
                                        )
                                    ),
                                    .hr()
                                )
                        })

                    )
                )
            )
        }

        override func navMenuItems() -> [NavMenuItem] {
            [.supporters, .addPackage, .faq]
        }
    }
}
