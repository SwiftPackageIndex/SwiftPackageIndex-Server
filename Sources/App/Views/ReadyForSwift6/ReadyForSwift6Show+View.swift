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
                .p("The Swift 6 language mode prevents data races at compile time. When you opt into Swift 6 mode, the compiler will produce errors when your code has a risk of concurrent access, turning hard-to-debug runtime failures into compiler errors."),
                .p("To track the progress of the Swift package ecosystem, the Swift Package Index is running regular package compatibility checks across all packages in the index."),
                .p(
                    .text("For help migrating your project's code, see the "),
                    .a(
                        .href("https://www.swift.org/migration/documentation/migrationguide/"),
                        .text("Swift 6 language mode migration guide")
                    ),
                    .text(".")
                ),
                .h3(
                    .id("total-zero-errors"),
                    "Total packages with Swift 6 zero data race safety errors"
                ),
                .p("This chart shows packages with zero data race safety compiler diagnostics during a successful build on at least one tested platform."),
                model.readyForSwift6Chart(kind: .compatiblePackages, includeTotals: true),
                .h3(
                    .id("total-errors"),
                    "Total Swift 6 data race safety errors"
                ),
                .p(
                    .text("This chart shows the total number of all data race safety diagnostics across "),
                    .em("all"),
                    .text(" packages.")
                ),
                model.readyForSwift6Chart(kind: .totalErrors),
                .h3(
                    .id("faq"),
                    "Frequently asked questions"
                ),
                .p(
                    .strong(.text("Q: ")),
                    .text("What is a “data race safety error”?")
                ),
                .p(
                    .strong(.text("A: ")),
                    .text("Swift 6 introduces complete concurrency checking, a compiler feature that checks your code for data race safety. The number of data race safety errors reflects how many issues the compiler detected relating to these concurrency or data race checks. The total errors chart plots the total number of these errors summed across all packages.")
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
                    .text("Yes. These charts plot the status of packages as if every package had opted in to the Swift 6 language mode and enabled “complete” concurrency checking. We pass "),
                    .code("-strict-concurrency=complete"),
                    .text(" to either "),
                    .code("swift build"),
                    .text(" or "),
                    .code("xcodebuild"),
                    .text(" to achieve this by enabling all data race safety checks in the compiler.")
                ),
                .hr(
                    .class("minor")
                ),
                .p(
                    .strong(.text("Q: ")),
                    .text("Are packages that show zero data race compiler diagnostics guaranteed to be safe from data race errors?")
                ),
                .p(
                    .strong(.text("A: ")),
                    .text("No. We gather data on data race safety from Swift compiler diagnostics with “complete” concurrency checks enabled. We can’t tell if the diagnostics produce zero errors due to a genuine lack of data race safety errors or whether errors have been suppressed using techniques like "),
                    .code("@unchecked Sendable"),
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
                    .text("Data race safety diagnostics are determined in different stages of the compiler. For example, type checking produces some data race safety errors, and others are diagnosed during control-flow analysis after code generation. If type checking produces errors, the compiler will not proceed to code generation, so testing with "),
                    .code("-swift-version 6"),
                    .text(" would show fewer errors than really exist across the package ecosystem.")
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
                    .text("We are not testing every package in the index. Instead, we are testing packages that are under some kind of active development. For this test, we define “all packages” in the chart to be any package having at least one commit to their repository in the last year. We took a snapshot of active packages on the 19th of March 2024, and the “all packages” data set includes 3,395 packages. The data set also excludes any new packages added after the 19th March.")
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
                        .href("https://www.swift.org/sswg/incubated-packages.html"),
                        .text("Swift Server Workgroup incubated packages list")
                    ),
                    .text(".")
                )
            )
        }
    }
}
