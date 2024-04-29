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

extension ReadyForSwift6Show {
    class View: PublicPage {
        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }

        override func pageTitle() -> String? {
            return "Ready for Swift 6"
        }

        override func breadcrumbs() -> [Breadcrumb] {
            [
                Breadcrumb(title: "Home", url: SiteURL.home.relativeURL()),
                Breadcrumb(title: "Ready for Swift 6")
            ]
        }

        override func content() -> Node<HTML.BodyContext> {
            .group(
                .h2("Ready for Swift 6"),
                .p("Swift 6 brings with it the ability to check your code for concurrency and data race issues. If switched on, the Swift compiler will produce errors where you could have data races."),
                .p(.text("For help migrating your code, see the "),
                   .a(
                    .href("https://example.com"),
                    .text("Swift 6 language mode migration guide")
                   ),
                   .text(" or the "),
                   .a(                    .href("https://example.com"),
                                          .text("Swift 6 release blog post")
                   )),
                .p("To track the progress of the Swift package ecosystem, the Swift Package Index is running regular package compatibility checks across all packages in the index."),
                .h3("Total packages compatible with Swift 6"),
                model.readyForSwift6Chart(kind: .compatiblePackages),
                .h3("Total Swift 6 concurrency errors"),
                model.readyForSwift6Chart(kind: .totalErrors)
            )
        }
    }
}
