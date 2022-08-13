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

enum MaintainerInfoIndex {

    class View: PublicPage {

        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }

        override func pageTitle() -> String? {
            "\(model.packageName) &ndash; Maintainer Information"
        }

        override func pageDescription() -> String? {
            "Are you a maintainer of \(model.packageName)? Get information on how to present your package on the Swift Package Index in the best way."
        }

        override func breadcrumbs() -> [Breadcrumb] {
            [
                Breadcrumb(title: "Home", url: SiteURL.home.relativeURL()),
                Breadcrumb(title: model.repositoryOwnerName, url: SiteURL.author(.value(model.repositoryOwner)).relativeURL()),
                Breadcrumb(title: model.packageName, url: SiteRoute.relativeURL(for: .package(owner: model.repositoryOwner, repository: model.repositoryName))),
                Breadcrumb(title: "Information for Maintainers"),
            ]
        }

        override func content() -> Node<HTML.BodyContext> {
            .div(
                .h2("Information for \(model.packageName) Maintainers"),
                .p(
                    .text("Are you the author, or a maintainer of "),
                    .a(
                        .href(SiteRoute.absoluteURL(for: .package(owner: model.repositoryOwner, repository: model.repositoryName))),
                        .text(model.packageName)
                    ),
                    .text("? "),
                    .text("Here's what you need to know to make your package's page on the Swift Package Index, and your README both show the best information about your package.")
                ),
                .h3("Compatibility Badges"),
                .p("You can add ",
                    .a(
                        .href("https://shields.io"),
                        "shields.io"
                    ),
                    " badges to your package's README file. Display your package's compatibility with recent versions of Swift, or with different platforms, or both!"
                ),
                .strong("Swift Version Compatibility Badge"),
                .div(
                    .class("markdown-badges"),
                    model.badgeMarkdowDisplay(for: .swiftVersions),
                    .img(
                        .alt("Swift Version Compatibility for \(model.packageName)"),
                        .src(model.badgeURL(for: .swiftVersions))
                    )
                ),
                .strong("Platform Compatibility Badge"),
                .div(
                    .class("markdown-badges"),
                    model.badgeMarkdowDisplay(for: .platforms),
                    .img(
                        .alt("Platform Compatibility for \(model.packageName)"),
                        .src(model.badgeURL(for: .platforms))
                    )
                ),
                .p("Copy the Markdown above into your package's README file to show always-up-to-date compatibility status for your package."),
                .h3("Build Compatibility"),
                .p(
                    .text("For information on improving your "),
                    .a(
                        .href(SiteURL.package(.value(model.repositoryOwner), .value(model.repositoryName), .builds).relativeURL()),
                        "package's build results"
                    ),
                    .text(", including why you might want to add a "),
                    .code(".spi.yml"),
                    .text(" which controls the Swift Package Index build system, see the "),
                    .a(
                        .href(SiteURL.docs(.builds).relativeURL()),
                        "build system documentation"
                    ),
                    .text(".")
                )
            )
        }
    }
}
