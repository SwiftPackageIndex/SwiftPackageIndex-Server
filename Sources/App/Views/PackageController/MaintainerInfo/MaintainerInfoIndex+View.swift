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

        enum Anchor: String {
            case spiHosting = "Host-DocC-documentation-in-the-Swift-Package-Index"
            case selfHosting = "Configure-a-documentation-URL-for-existing-documentation"
            case targetsAndSchemes = "Control-Targets-and-Schemes"
            case linuxImages = "Images-for-Linux"
        }

        static func spiManifestCommonUseCasesDocLink(_ anchor: Anchor) -> String {
            SiteURL.relativeURL(owner: "SwiftPackageIndex",
                                repository: "SPIManifest",
                                documentation: .internal(docVersion: .current(), archive: "spimanifest"),
                                fragment: .documentation,
                                path: "spimanifest/commonusecases#\(anchor)")
        }
        
        static func spiManifestDocLink() -> String {
            SiteURL.relativeURL(owner: "SwiftPackageIndex",
                                repository: "SPIManifest",
                                documentation: .internal(docVersion: .current(), archive: "spimanifest"),
                                fragment: .documentation)
        }

        override func content() -> Node<HTML.BodyContext> {
            let scoreCategories = model.scoreCategories()
            return .div(
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
                                .href(Self.spiManifestCommonUseCasesDocLink(.spiHosting)),
                                "Hosting your documentation"
                            ),
                            " on the Swift Package Index site."
                        )
                    ),
                    .li(
                        .p(
                            .a(
                                .href(Self.spiManifestCommonUseCasesDocLink(.selfHosting)),
                                "Configure a link to external self-hosted documentation"
                            ),
                            "."
                        )
                    ),
                    .li(
                        .p(
                            .a(
                                .href(Self.spiManifestCommonUseCasesDocLink(.targetsAndSchemes)),
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
                                .href(Self.spiManifestCommonUseCasesDocLink(.linuxImages)),
                                "configure base images for Linux builds"
                            ),
                            "."
                        )
                    )
                ),  // end of ul
                .p(
                    "See the ",
                    .a(
                        .href(Self.spiManifestDocLink()),
                        "SPIManifest package documentation"
                    ),
                    " for more details, or use our ",
                    .a(
                        .href(SiteURL.validateSPIManifest.relativeURL()),
                        .text("online manifest validation helper")
                    ),
                    " to validate your ", .code(".spi.yml"), " file."
                ),
                .div(
                    .id("package-score"),
                    .h3("Package Score"),
                    .p(
                        "This package has a total score of \(model.score) points. The Swift Package Index uses package score in combination with the relevancy of a search query to influence the ordering of search results."
                    ),
                    .p(
                        "The score is currently evaluated based on \(scoreCategories.count) traits, and the breakdown of each trait is shown below."
                    ),
                    .div(
                        .class("package-score"),
                        .text("Total – \(model.score) points")
                    ),
                    .div(
                        .class("package-score-breakdown"),
                        Model.packageScoreCategories(for: scoreCategories)
                    ),
                    .p(
                        "The package score is a work in progress. We have an ",
                       .a(
                        .href(model.packageScoreDiscussionURL),
                        "always-open discussion thread"
                       ),
                       .text(" if you are interested in providing feedback on existing traits or would like to propose new ones.")
                    )
                )
            )
        }
    }
}
