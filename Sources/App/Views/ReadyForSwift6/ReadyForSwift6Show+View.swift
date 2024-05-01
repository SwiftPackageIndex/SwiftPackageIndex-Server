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
                   .a(
                    .href("https://example.com"),
                    .text("Swift 6 release blog post")
                   )),
                .p("To track the progress of the Swift package ecosystem, the Swift Package Index is running regular package compatibility checks across all packages in the index."),
                .h3("Total packages compatible with Swift 6"),
                model.readyForSwift6Chart(kind: .compatiblePackages),
                .h3("Total Swift 6 concurrency errors"),
                model.readyForSwift6Chart(kind: .totalErrors),
                .h3("Frequently asked questions"),
                .p(
                    .strong(.text("Q: ")),
                    .text("What does “compatible” mean in the chart of compatible packages?")
                ),
                .p(
                    .strong(.text("A: ")),
                    .text("We define compatibility in the same way we do on package pages. If any build of the package completes successfully on any of our tested platforms (macOS via SwiftPM, macOS via XcodeBuild, iOS, visionOS, watchOS, tvOS, or Linux) then that build is deemed compatible with the Swift version.")
                ),
                .hr(
                    .class("minor")
                ),
                .p(
                    .strong(.text("Q: ")),
                    .text("What does “total concurrency errors” mean?")
                ),
                .p(
                    .strong(.text("A: ")),
                    .text("Sven: Can you replace this with a short description of these errors, please?")
                ),
                .hr(
                    .class("minor")
                ),
                .p(
                    .strong(.text("Q: ")),
                    .text("What packages are in the “all packages” data set?")
                ),
                .p(
                    .strong(.text("A: ")),
                    .text("We are not testing every package in the index. Instead, we are testing packages that are under some kind of active development. For this test, we define “all packages” in the chart to be any package having at least one commit to their repository in the last year. We took a snapshot of active packages on the 19th of March 2024, and the “all packages” data set includes 3,393 packages. The data set also excludes any new packages added after the 19th March.")
                ),
                .hr(
                    .class("minor")
                ),
                .p(
                    .strong(.text("Q: ")),
                    .text("What packages are in the “Apple packages” and “SSWG incubated packages” data sets?")
                ),
                .p(
                    .strong(.text("A: ")),
                    .text("It’s interesting to look at some slices of curated package lists in addition to overall compatibility. Apple should be leading from the front, so the “Apple packages” data set is "),
                    .a(
                        .href(SiteURL.author(.value("apple")).relativeURL()),
                        .text("all packages authored by Apple")
                    ),
                    .text(", again with the same criteria as above applied. Nothing newer than March 19th and nothing without commits in the last year. The SSWG incubated data set is the same idea but sourced from the "),
                    .a(
                        .href("https://www.swift.org/sswg/#projects"),
                        .text("Swift Server Workgroup incubated packages list")
                    ),
                    .text(".")
                )
            )
        }
    }
}
