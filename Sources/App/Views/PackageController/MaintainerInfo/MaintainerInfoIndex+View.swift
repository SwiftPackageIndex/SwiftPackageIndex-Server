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

enum MaintainerInfoIndex {

    class View: PublicPage {

        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }

        override func allowIndexing() -> Bool {
            // Block this page from being indexed by search engines.
            return false
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
                Breadcrumb(title: model.packageName, url: SiteURL.package(.value(model.repositoryOwner), .value(model.repositoryName), .none).relativeURL()),
                Breadcrumb(title: "Information for Maintainers"),
            ]
        }

        private enum Anchor: String {
            case spiHosting = "Host-DocC-documentation-in-the-Swift-Package-Index"
            case selfHosting = "Configure-a-documentation-URL-for-existing-documentation"
            case targetsAndSchemes = "Control-Targets-and-Schemes"
            case linuxImages = "Images-for-Linux"
        }

        private func docLink(_ anchor: Anchor) -> String {
            SiteURL.relativeURL(owner: "SwiftPackageIndex",
                                repository: "SPIManifest",
                                documentation: .universal,
                                fragment: .documentation,
                                path: "spimanifest/commonusecases#\(anchor)")
        }

        override func content() -> Node<HTML.BodyContext> {
            .div(
                .h2("Information for \(model.packageName) Maintainers"),
                .p(
                    .text("Are you the author, or a maintainer of "),
                    .a(
                        .href(SiteURL.package(.value(model.repositoryOwner), .value(model.repositoryName), .none).absoluteURL()),
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

                .h3("Manifest File"),
                .p(
                    "You can control more aspects of how the Swift Package Index treats your package repository, including improving build compatibility results and opting into automated DocC documentation hosting."
                ),
                .p(
                    "As the Swift Package Index scans your package repository, it will look for a manifest file named ",
                    .code(".spi.yml"),
                    ". If found, here are some of the things you can control or enable with it:"
                ),
                .ul(
                    .li(
                        .p(
                            .a(
                                .href(docLink(.spiHosting)),
                                "Hosting your documentation"
                            ),
                            " on the Swift Package Index site."
                        )
                    ),
                    .li(
                        .p(
                            .a(
                                .href(docLink(.selfHosting)),
                                "Configure a link to external self-hosted documentation"
                            ),
                            "."
                        )
                    ),
                    .li(
                        .p(
                            .a(
                                .href(docLink(.targetsAndSchemes)),
                                "Control build targets and schemes"
                            ),
                            " to improve your ",
                            .a(
                                .href(SiteURL.package(.value(model.repositoryOwner), .value(model.repositoryName), .builds).relativeURL()),
                                "package's build results"
                            ),
                            ".",
                            " For more details about the build system, see the ",
                            .a(
                                .href(SiteURL.docs(.builds).relativeURL()),
                                "build system documentation"
                            ),
                            "."
                        )
                    ),
                    .li(
                        .p(
                            "If your builds require additional operating system-level dependencies to succeed, you can ",
                            .a(
                                .href(docLink(.linuxImages)),
                                "configure base images for Linux builds"
                            ),
                            "."
                        )
                    )
                ),  // end of ul
                .p(
                    "See the ",
                    .a(
                        .href(SiteURL.relativeURL(owner: "SwiftPackageIndex",
                                                  repository: "SPIManifest",
                                                  documentation: .universal,
                                                  fragment: .documentation,
                                                  path: "spimanifest")),
                        "SPIManifest package documentation"
                    ),
                    " for more details, or use our ",
                    .a(
                        .href(SiteURL.validateSPIManifest.relativeURL()),
                        .text("online manifest validation helper")
                    ),
                    " to validate your ", .code(".spi.yml"), "file."
                ),
                .div(
                    .id("package-score"),
                    .h3("Package Score"),
                    .p(
                        "Based on our analysis, this package has the total score of \(model.score). In combination with the relevancy of a search query, we use the package score to partially influence the ordering of search results on the Swift Package Index."
                    ),
                    .p(
                        "The score is currently evaluated based on \(model.scoreCategories.count) traits and the breakdown of each trait is shown below."
                    ),
                    .div(
                        .class("package-score"),
                        .text("Total – \(model.score) points")
                    ),
                    .div(
                        .class("container"),
                        model.packageScoreCategories()
                    ),
                    .p("If you are interested in providing feedback for the package score, please submit ideas in the ",
                       .a(
                        .href(model.packageScoreDiscussionURL),
                        "discussion thread."
                       )
                    )
                )
            )
        }
    }
}
