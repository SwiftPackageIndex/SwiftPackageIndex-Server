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
        
        override func content() -> Node<HTML.BodyContext> {
            .group(
                .unwrap(packageSchema) {
                    .structuredData($0)
                },
                .h2(.text(model.title)),
                .small(
                    .a(
                        .id("package_url"),
                        .href(model.url),
                        .text(model.url)
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
                readmeSection()
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
                .class("main_metadata"),
                .ul(
                    model.authorsListItem(),
                    model.historyListItem(),
                    model.activityListItem(),
                    model.licenseListItem(),
                    model.starsListItem(),
                    model.librariesListItem(),
                    model.executablesListItem()
                )
            )
        }

        func mainColumnCompatibility() -> Node<HTML.BodyContext> {
            .section(
                .class("main_compatibility"),
                .h3("Compatibility"),
                .div(
                    .class("matrices"),
                    model.swiftVersionCompatibilitySection(),
                    model.platformCompatibilitySection()
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
                            .href(SiteURL.package(.value(model.repositoryOwner), .value(model.repositoryName), .builds).relativeURL()),
                            "Full Package Compatibility Report"
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
            .turboFrame(id: "readme",
                        source: SiteURL.package(.value(model.repositoryOwner),
                                                .value(model.repositoryName),
                                                .readme).relativeURL(),
                        // Until the content is loaded, substitute a spinner.
                        .spinner()
            )
        }
    }
}
