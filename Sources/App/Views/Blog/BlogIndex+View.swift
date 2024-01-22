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

import Plot

extension BlogIndex {

    class View: PublicPage {
        
        let model: Model
        
        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }
        
        override func pageTitle() -> String? {
            return "The Swift Package Index Blog"
        }

        override func bodyClass() -> String? {
            "blog"
        }

        override func breadcrumbs() -> [Breadcrumb] {
            [
                Breadcrumb(title: "Home", url: SiteURL.home.relativeURL()),
                Breadcrumb(title: "Blog")
            ]
        }
        
        override func content() -> Node<HTML.BodyContext> {
            .ul(
                .group(
                    model.summaries.map({ summary -> Node<HTML.ListContext> in
                            .li(
                                .a(
                                    .href(summary.slug),
                                    .text(summary.title)
                                )
                            )
                    })

                )
            )
        }
        
        override func navMenuItems() -> [NavMenuItem] {
            [.supporters, .addPackage, .faq]
        }
    }
}