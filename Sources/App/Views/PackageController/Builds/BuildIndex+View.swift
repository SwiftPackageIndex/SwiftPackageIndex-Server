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


enum BuildIndex {

    class View: PublicPage {

        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }

        override func pageTitle() -> String? {
            "\(model.packageName) &ndash; Build Results"
        }

        override func pageDescription() -> String? {
            "The latest compatibility build results for \(model.packageName), showing compatibility across \(Build.Platform.allActive.count) platforms with \(SwiftVersion.allActive.count) versions of Swift."
        }

        override func breadcrumbs() -> [Breadcrumb] {
            [
                Breadcrumb(title: "Home", url: SiteURL.home.relativeURL()),
                Breadcrumb(title: model.ownerName, url: SiteURL.author(.value(model.owner)).relativeURL()),
                Breadcrumb(title: model.packageName, url: SiteURL.package(.value(model.owner), .value(model.repositoryName), .none).relativeURL()),
                Breadcrumb(title: "Build Results")
            ]
        }

        override func content() -> Node<HTML.BodyContext> {
            .div(
                .h2("Build Results"),
                .p(
                    .strong("\(model.completedBuildCount)"),
                    .text(" completed \("build".pluralized(for: model.completedBuildCount)) for "),
                    .a(
                        .href(model.packageURL),
                        .text(model.packageName)
                    ),
                    .text(".")
                ),
                .p(
                    "If you are the author of this package and see unexpected build failures, please check the ",
                    .a(
                        .href(SiteURL.docs(.builds).relativeURL()),
                        "build system documentation"
                    ),
                    " to see how we derive build parameters. If you still see surprising results, please ",
                    .a(
                        .href(ExternalURL.raiseNewIssue),
                        "raise an issue"
                    ),
                    "."
                ),
                .forEach(SwiftVersion.allActive.reversed()) { swiftVersion in
                    .group(
                        .hr(),
                        .h3(.text(swiftVersion.longDisplayName)),
                        .ul(
                            .class("matrix builds"),
                            .group(model.buildMatrix[swiftVersion].map(\.node))
                        )
                    )
                }
            )
        }

    }
}
