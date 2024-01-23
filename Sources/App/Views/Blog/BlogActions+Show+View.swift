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

extension BlogActions {

    enum Show {

        class View: PublicPage {

            let model: Model.PostSummary

            init(path: String, model: Model.PostSummary) {
                self.model = model
                super.init(path: path)
            }

            override func pageTitle() -> String? {
                return "\(model.title) on the Swift Package Index Blog"
            }

            override func postHead() -> Node<HTML.HeadContext> {
                .group(
                    .link(
                        .rel(.stylesheet),
                        .href("https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/default.min.css")
                    ),
                    .script(
                        .src("https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js")
                    )
                )
            }

            override func postBody() -> Node<HTML.BodyContext> {
                .script(
                    .raw("hljs.highlightAll();")
                )
            }

            override func bodyClass() -> String? {
                "blog"
            }

            override func breadcrumbs() -> [Breadcrumb] {
                [
                    Breadcrumb(title: "Home", url: SiteURL.home.relativeURL()),
                    Breadcrumb(title: "Blog", url: SiteURL.blog.relativeURL()),
                    Breadcrumb(title: model.title)
                ]
            }

            override func content() -> Node<HTML.BodyContext> {
                .group(
                    .h2(
                        .class("post-title"),
                        .text(model.title)
                    ),
                    .small(
                        model.publishInformation()
                    ),
                    .hr(
                        .class("post-title")
                    ),
                    .article(
                        .class("blog-post"),
                        .raw(model.postMarkdown)
                    ),
                    .hr(),
                    .section(
                        .class("about-this-blog"),
                        .h3("About this blog"),
                        .text("The "),
                        .a(
                            .href(SiteURL.home.relativeURL()),
                            "Swift Package Index"
                        ),
                        .text(" is a search engine and metadata index for Swift packages. Our main goal is to help you make better decisions about the dependencies you include in your apps and projects. If you're new here, the best place to get started is "),
                        .a(
                            .href(SiteURL.home.relativeURL()),
                            "by searching"
                        ),
                        .text(".")
                    )
                )
            }

            override func navMenuItems() -> [NavMenuItem] {
                [.supporters, .addPackage, .faq]
            }
        }

    }

}
