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

import Ink
import Vapor
import Plot


extension PackageShow {

    class View: PublicPage {

        let model: API.PackageController.GetRoute.Model
        let packageSchema: API.PackageSchema?

        init(path: String, model: API.PackageController.GetRoute.Model,
             packageSchema: API.PackageSchema?) {
            self.model = model
            self.packageSchema = packageSchema
            super.init(path: path)
        }
        
        override func pageCanonicalURL() -> String? {
            SiteURL.package(.value(model.repositoryOwner), .value(model.repositoryName), .none).absoluteURL()
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
                    .class("two-column v-end"),
                    .div(
                        .class("package-title"),
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
                        .h5("Package clause"),
                        .unwrap(model.packageDependencyCodeSnippet(for: .release), {
                            model.spmDependencyForm(link: $0, cssClass: "stable")
                        }),
                        .unwrap(model.packageDependencyCodeSnippet(for: .preRelease), {
                            model.spmDependencyForm(link: $0, cssClass: "beta")
                        }),
                        .unwrap(model.packageDependencyCodeSnippet(for: .defaultBranch), {
                            model.spmDependencyForm(link: $0, cssClass: "branch")
                        }),
                        .unwrap(model.products, { products in
                                .group(
                                .h5("Product clause"),
                                .p(
                                    .label(.attribute(named: "for", value: "products"), "Choose a product:"),
                                    " ",
                                    .select(
                                        .attribute(named: "name", value: "products"),
                                        .id("products"),
                                        .forEach(products, { product in
                                                .element(named: "option", nodes: [
                                                    .attribute(named: "value", value: product.name),
                                                    .text(product.name)
                                                ])
                                        })
                                    )
                                ),
                                // FIXME: insert selected product into `valueToCopy`
                                .copyableInputForm(buttonName: "Copy Code Snippet",
                                                   eventName: "Copy SwiftPM manifest clause button",
                                                   valueToCopy: ".product(name: &quot;FIXME&quot;, package: &quot;FIXME&quot;)")
                                )
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
                    .class("main-metadata"),
                    model.authorsListItem(),
                    model.archivedListItem(),
                    model.binaryTargetsItem(),
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
                    .class("two-column v-end"),
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
                .class("sidebar-links"),
                .ul(
                    .li(
                        .a(
                            .class("github"),
                            .href(model.gitHubRepositoryUrl),
                            "View on GitHub"
                        )
                    ),
                    .li(
                        .class("try-in-playground"),
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
                    .unwrap(model.documentationTarget) { target in
                            .li(
                                .a(
                                    .href(SiteURL.relativeURL(owner: model.repositoryOwner,
                                                              repository: model.repositoryName,
                                                              documentation: target,
                                                              fragment: .documentation)),
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
                .class("sidebar-package-authors"),
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
            .unwrap(packageSchema?.publicationDates) { dates in
                .section(
                    .hr(),
                    .p(
                        .lastUpdatedTime(dates.dateModified)
                    )
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
