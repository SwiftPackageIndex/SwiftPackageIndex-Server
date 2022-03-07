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

import Ink
import Vapor
import Plot

enum PackageShow {
    
    class View: PublicPage {
        
        let model: Model
        let packageSchema: PackageSchema?

        init(path: String, model: Model, packageSchema: PackageSchema?) {
            self.model = model
            self.packageSchema = packageSchema
            super.init(path: path)
        }
        
        override func pageTitle() -> String? {
            model.title
        }
        
        override func pageDescription() -> String? {
            var description = "\(model.title) by \(model.repositoryOwnerName) on the Swift Package Index"
            if let summary = model.summary {
                description += " – \(summary)"
            }
            return description
        }
        
        override func bodyClass() -> String? {
            "package"
        }

        override func bodyComments() -> Node<HTML.BodyContext> {
            .group(
                .comment(model.packageId.uuidString),
                .comment(model.score.map(String.init) ?? "unknown")
            )
        }
        
        override func postBody() -> Node<HTML.BodyContext> {
            .unwrap(packageSchema) {
                .structuredData($0)
            }
        }
        
        override func content() -> Node<HTML.BodyContext> {
            .group(
                .div(
                    .class("two_column"),
                    .h2(.text(model.title)),
                    .spiPanel(
                        buttonText: "Use this Package",
                        .p(
                            .text("How you add this package to your project depends on what kind of project you're developing.")
                        ),
                        .h4("When working with an Xcode project:"),
                        model.xcodeprojDependencyForm(packageUrl: model.url),
                        .h4("When working with a Swift Package Manager manifest:"),
                        .unwrap(model.releases.stable, {
                            model.spmDependencyForm(releaseLink: $0.link, cssClass: "stable")
                        }),
                        .unwrap(model.releases.beta, {
                            model.spmDependencyForm(releaseLink: $0.link, cssClass: "beta")
                        }),
                        .unwrap(model.releases.latest, {
                            model.spmDependencyForm(releaseLink: $0.link, cssClass: "branch")
                        })
                    )
                ),
                .hr(.class("tight")),
                .p(
                    .class("summary"),
                    .unwrap(model.summary) { summary in
                        .text(summary.replaceShorthandEmojis())
                    }
                ),
                detailsSection(),
                tabBar(),
                .noscript(
                    .text("JavaScript must be enabled to load the README and Release Notes tabs.")
                ),
                readmeSection(),
                releaseSection()
            )
        }

        func detailsSection() -> Node<HTML.BodyContext> {
            .article(
                .class("details"),
                .div(
                    .class("two_column"),
                    mainColumnMetadata(),
                    sidebarLinks()
                ),
                .hr(
                    .class("minor")
                ),
                .div(
                    .class("two_column"),
                    mainColumnCompatibility(),
                    sidebarVersions()
                )
            )
        }

        func mainColumnMetadata() -> Node<HTML.BodyContext> {
            .section(
                .ul(
                    .class("main_metadata"),
                    model.authorsListItem(),
                    model.archivedListItem(),
                    model.historyListItem(),
                    model.activityListItem(),
                    model.dependenciesListItem(),
                    model.licenseListItem(),
                    model.starsListItem(),
                    model.librariesListItem(),
                    model.executablesListItem(),
                    model.keywordsListItem()
                )
            )
        }

        func mainColumnCompatibility() -> Node<HTML.BodyContext> {
            .section(
                .class("main_compatibility"),
                .h3("Compatibility"),
                .div(
                    .class("matrices"),
                    .if(model.hasBuildInfo,
                        .group(
                            model.swiftVersionCompatibilityList(),
                            model.platformCompatibilityList()
                        ),
                        else: .group(
                            .p(
                                "This package currently has no compatibility information. Builds to determine package compatibility are starting, and compatibility information will appear soon. If this message persists for more than a few minutes, please ",
                                .a(
                                    .href(ExternalURL.raiseNewIssue),
                                    "raise an issue"
                                ),
                                "."
                            )
                        )
                    )
                )
            )
        }

        func sidebarLinks() -> Node<HTML.BodyContext> {
            .section(
                .class("sidebar_links"),
                .ul(
                    .li(
                        .class("try_in_playground"),
                        .a(
                            .href("spi-playgrounds://open?dependencies=\(model.repositoryOwner)/\(model.repositoryName)"),
                            "Try in a Playground"
                        ),
                        .div(
                            .id("app_download_explainer"),
                            .class("hidden"),
                            .strong("Launching the SPI Playgrounds app&hellip;"),
                            .p(
                                .text("If nothing happens, you may not have the app installed. "),
                                .a(
                                    .href(SiteURL.tryInPlayground.relativeURL(parameters: [QueryParameter(key: "dependencies", value: "\(model.repositoryOwner)/\(model.repositoryName)")])),
                                    "Download the Swift Package Index Playgrounds app"
                                ),
                                .text(" and try again.")
                            )
                        )
                    ),
                    .li(
                        .a(
                            .href(model.url),
                            "View on GitHub"
                        )
                    ),
                    .li(
                        .a(
                            .href(SiteURL.author(.value(model.repositoryOwner)).relativeURL()),
                            "More packages from this author"
                        )
                    ),
                    .li(
                        .a(
                            .href(SiteURL.package(.value(model.repositoryOwner), .value(model.repositoryName), .maintainerInfo).relativeURL()),
                            "Do you maintain this package?"
                        )
                    )
                )
            )
        }

        func sidebarVersions() -> Node<HTML.BodyContext> {
            .section(
                .class("sidebar_versions"),
                .h3("Versions"),
                .ul(
                    model.stableReleaseMetadata(),
                    model.betaReleaseMetadata(),
                    model.defaultBranchMetadata()
                )
            )
        }

        func readmeSection() -> Node<HTML.BodyContext> {
            .turboFrame(id: "readme_page",
                        source: SiteURL.package(.value(model.repositoryOwner),
                                                .value(model.repositoryName),
                                                .readme).relativeURL(),
                        .data(named: "tab-page", value: "readme"),
                        .class("tab_page"),
                        .div(
                            .class("min_height_spacer"),
                            .spinner()
                        )
            )
        }
        
        func releaseSection() -> Node<HTML.BodyContext> {
            .turboFrame(id: "releases_page",
                        source: SiteURL.package(.value(model.repositoryOwner),
                                                .value(model.repositoryName),
                                                .releases).relativeURL(),
                        .data(named: "tab-page", value: "releases"),
                        .class("tab_page hidden"),
                        .div(
                            .class("min_height_spacer"),
                            .spinner()
                        )
            )
        }
        
        func tabBar() -> Node<HTML.BodyContext> {
            .spiTabBar(
                .ul(
                    .li(
                        .id("readme"),
                        .class("active"),
                        .data(named: "tab", value: "readme"),
                        "README"
                    ),
                    .li(
                        .id("releases"),
                        .data(named: "tab", value: "releases"),
                        "Release Notes"
                    )
                )
            )
        }
    }
}
