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
                .p("The Swift 6 language mode prevents data-races at compile time. When you opt into Swift 6 mode, the compiler will produce errors when your code has a risk of concurrent access, turning hard-to-debug runtime failures into compiler errors."),
                .p("To track the progress of the Swift package ecosystem, the Swift Package Index is running regular package compatibility checks across all packages in the index."),
                // TODO: Comment back in when the URLs to the migration guide and/or launch post are available.
                // .p(
                //     .text("For help migrating your code, see the "),
                //     .a(
                //         .href("https://example.com"),
                //         .text("Swift 6 language mode migration guide")
                //     ),
                //     .text(" or the "),
                //     .a(
                //         .href("https://example.com"),
                //         .text("Swift 6 release blog post")
                //     )
                // ),
                .h3("Total packages compatible with Swift 6"),
                .p("Packages with zero data-race safety compiler diagnostics during a successful build on at least one tested platform."),
                model.readyForSwift6Chart(kind: .compatiblePackages),
                .h3("Total Swift 6 concurrency errors"),
                .p(
                    .text("The total number of all data-race safety diagnostics across "),
                    .em("all"),
                    .text(" packages.")
                ),
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
                    .text("Are additional parameters added to the build command for these tests compared to the “standard” Swift Package Index builds that determine Swift version compatibility on package pages?")
                ),
                .p(
                    .strong(.text("A: ")),
                    .text("Yes. The builds that produce the results on this page have strict concurrency checking set to "),
                    .code("complete"),
                    .text(" to check for data race safety in Swift 6 language mode. We pass "),
                    .code("-strict-concurrency=complete"),
                    .text(" to either "),
                    .code("swift build"),
                    .text(" or "),
                    .code("xcodebuild"),
                    .text(".")
                ),
                .hr(
                    .class("minor")
                ),
                .p(
                    .strong(.text("Q: ")),
                    .text("Why use "),
                    .code("-strict-concurrency=complete"),
                    .text(" instead of "),
                    .code("-swift-version 6"),
                    .text("?")
                ),
                .p(
                    .strong(.text("A: ")),
                    .text("Data-race safety diagnostics are determined in different stages of the compiler. For example, type checking produces some data-race safety errors, and others are diagnosed during control-flow analysis after code generation. If type checking produces errors, the compiler will not proceed to code generation, so testing with "),
                    .code("-swift-version 6"),
                    .text(" would show fewer errors than really exist across the package ecosystem.")
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
                    .text("Swift 6 introduces complete concurrency checking, a compiler feature that checks your code for data-race safety. The number of concurrency errors reflects how many issues the compiler detected relating to these concurrency or data-race checks. The total errors chart plots the total number of these errors summed across all packages.")
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
