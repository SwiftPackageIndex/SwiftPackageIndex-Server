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

        private static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.locale = .init(identifier: "en_GB")

            return formatter
        }()

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

        override func breadcrumbs() -> [Breadcrumb] {
            [
                Breadcrumb(title: "Home", url: SiteURL.home.relativeURL()),
                Breadcrumb(title: model.repositoryOwnerName, url: SiteURL.author(.value(model.repositoryOwner)).relativeURL()),
                Breadcrumb(title: model.title)
            ]
        }

        override func postBody() -> Node<HTML.BodyContext> {
            .unwrap(packageSchema) {
                .structuredData($0)
            }
        }

        override func content() -> Node<HTML.BodyContext> {
            .group(
                .div(
                    .class("two-column v_end"),
                    .div(
                        .class("package_title"),
                        .h2(.text(model.title)),
                        .small(
                            .a(
                                .href(model.gitHubOwnerUrl),
                                .text(model.repositoryOwner)
                            ),
                            .span("/"),
                            .a(
                                .href(model.gitHubRepositoryUrl),
                                .text(model.repositoryName)
                            )
                        )
                    ),
                    .spiPanel(
                        buttonText: "Use this Package",
                        .p(
                            .text("How you add this package to your project depends on what kind of project you're developing.")
                        ),
                        .h4("When working with an Xcode project:"),
                        model.xcodeprojDependencyForm(packageUrl: model.url),
                        .h4("When working with a Swift Package Manager manifest:"),
                        .unwrap(model.dependencyCodeSnippets[.release], {
                            model.spmDependencyForm(link: $0, cssClass: "stable")
                        }),
                        .unwrap(model.dependencyCodeSnippets[.preRelease], {
                            model.spmDependencyForm(link: $0, cssClass: "beta")
                        }),
                        .unwrap(model.dependencyCodeSnippets[.defaultBranch], {
                            model.spmDependencyForm(link: $0, cssClass: "branch")
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
                .spiTabBar(tabs: [
                    TabMetadata(id: "readme", title: "README"),
                    TabMetadata(id: "releases", title: "Release Notes")
                ], tabContent: [
                    readmeTabContent(),
                    releasesTabContent(),
                ]),
                visibleMetadataSection()
            )
        }

        func detailsSection() -> Node<HTML.BodyContext> {
            .article(
                .class("details two-column"),
                .section(
                    mainColumnMetadata(),
                    .hr(
                        .class("minor")
                    ),
                    mainColumnCompatibility()
                ),
                .section(
                    sidebarLinks(),
                    .hr(
                        .class("minor")
                    ),
                    sidebarVersions(),
                    .hr(
                        .class("minor")
                    ),
                    sidebarInfoForPackageAuthors()
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
                    model.pluginsListItem(),
                    model.keywordsListItem()
                )
            )
        }

        func mainColumnCompatibility() -> Node<HTML.BodyContext> {
            .section(
                .class("main-compatibility"),
                .div(
                    .class("two-column v_end"),
                    .h3("Compatibility"),
                    .a(
                        .href(SiteURL.package(.value(model.repositoryOwner), .value(model.repositoryName), .builds).relativeURL()),
                        .text("Full Build Results")
                    )
                ),
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
                        .a(
                            .href(model.gitHubRepositoryUrl),
                            "View on GitHub"
                        )
                    ),
                    .li(
                        .class("try_in_playground"),
                        .a(
                            .href("spi-playgrounds://open?dependencies=\(model.repositoryOwner)/\(model.repositoryName)"),
                            "Try in a Playground"
                        ),
                        .div(
                            .id("app-download-explainer"),
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
                    .unwrap(model.homepageUrl) { homepageUrl in
                        .li(
                            .a(
                                .href(homepageUrl),
                                "Package Homepage"
                            )
                        )
                    },
                    .unwrap(model.documentationMetadata) { metadata in
                        .li(
                            .a(
                                .href(model.relativeDocumentationURL(reference: metadata.reference, target: metadata.defaultArchive)),
                                .data(named: "turbo", value: String(false)),
                                "Documentation"
                            )
                        )
                    }
                )
            )
        }

        func sidebarVersions() -> Node<HTML.BodyContext> {
            .section(
                .class("sidebar-versions"),
                .ariaLabel("Versions"),
                .ul(
                    model.stableReleaseMetadata(),
                    model.betaReleaseMetadata(),
                    model.defaultBranchMetadata()
                )
            )
        }

        func sidebarInfoForPackageAuthors() -> Node<HTML.BodyContext> {
            .section(
                .class("sidebar_package_authors"),
                .small(
                    .strong("Do you maintain this package?"),
                    .text(" Get shields.io compatibility badges and learn how to control our build system. "),
                    .a(
                        .href(SiteURL.package(.value(model.repositoryOwner), .value(model.repositoryName), .maintainerInfo).relativeURL()),
                        "Learn more"
                    ),
                    .text(".")
                )
            )
        }

        func visibleMetadataSection() -> Node<HTML.BodyContext> {
            .unwrap(packageSchema?.publicationDates) {
                .section(
                    .hr(),
                    .p(.small(.text("Last updated on \(Self.dateFormatter.string(from: $0.dateModified))")))
                )
            }

        }

        func readmeTabContent() -> Node<HTML.BodyContext> {
            .turboFrame(
                id: "readme_content",
                source: SiteURL.package(.value(model.repositoryOwner),
                                        .value(model.repositoryName),
                                        .readme).relativeURL(),
                .data(named: "controller", value: "readme"),
                .data(named: "action", value: """
                        turbo:frame-load->readme#fixReadmeAnchors \
                        turbo:frame-load->readme#navigateToAnchorFromLocation
                        """),
                .div(.spinner())
            )
        }

        func releasesTabContent() -> Node<HTML.BodyContext> {
            .turboFrame(
                id: "releases_content",
                source: SiteURL.package(.value(model.repositoryOwner),
                                        .value(model.repositoryName),
                                        .releases).relativeURL(),
                .div(.spinner())
            )
        }
    }
}
