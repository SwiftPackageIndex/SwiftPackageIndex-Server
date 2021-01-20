import Ink
import Vapor
import Plot

enum PackageShow {
    
    class View: PublicPage {
        
        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }
        
        override func pageTitle() -> String? {
            model.title
        }
        
        override func pageDescription() -> String? {
            var description = "\(model.title) on the Swift Package Index"
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
                .h2(.text(model.title)),
                .small(
                    .a(
                        .id("package_url"),
                        .href(model.url),
                        .text(model.url)
                    )
                ),
                arenaButton(),
                .hr(),
                .p(
                    .class("summary"),
                    .unwrap(model.summary) { summary in
                        .text(summary.replaceShorthandEmojis())
                    }
                ),
                detailsSection(),
                supportSection(),
                readmeSection()
            )
        }

        func arenaButton() -> Node<HTML.BodyContext> {
            let environment = (try? Environment.detect()) ?? .development
            return .if(environment != .production,
                       .a(.href("slide://open?dependencies=\(model.repositoryOwner)/\(model.repositoryName)"), "🏟")
            )
        }

        func detailsSection() -> Node<HTML.BodyContext> {
            .article(
                .class("details"),
                mainColumn(),
                sidebarColumn()
            )
        }
        
        func mainColumn() -> Node<HTML.BodyContext> {
            .group(
                // Note: Adding *any* other markup other than the main sections here will break
                // layout. This is a grid layout, and every element is positioned manually.
                mainColumnMetadata(),
                mainColumnCompatibility()
            )
        }

        func mainColumnMetadata() -> Node<HTML.BodyContext> {
            .section(
                .class("main_metadata"),
                .ul(
                    .class("icons"),
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
                .h3("Package Compatibility"),
                model.swiftVersionCompatibilitySection(),
                model.platformCompatibilitySection()
            )
        }
        
        func sidebarColumn() -> Node<HTML.BodyContext> {
            // Note: Adding *any* other markup other than the main sections here will break
            // layout. This is a grid layout, and every element is positioned manually.
            .group(
                sidebarLinks(),
                sidebarVersions()
            )
        }

        func sidebarLinks() -> Node<HTML.BodyContext> {
            .section(
                .class("sidebar_links"),
                .ul(
                    .class("icons"),
                    .li(
                        .class("github"),
                        .a(
                            .href(model.url),
                            // TODO: Make "GitHub" dynamic.
                            "View on GitHub"
                        )
                    ),
                    .li(
                        .class("compatibility"),
                        .a(
                            .href(SiteURL.package(.value(model.repositoryOwner), .value(model.repositoryName), .builds).relativeURL()),
                            "Full Compatibility Report"
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

        func supportSection() -> Node<HTML.BodyContext> {
            .section(
                .class("support"),
                .p("The Swift Package Index is open-source, built and maintained by individuals rather than a company, and runs entirely on community donations. Please consider ",
                   .a(
                    .href("https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server"),
                    "supporting this project by sponsoring it"
                   ),
                   "."
                ),
                .a(
                    .href("https://github.com/sponsors/SwiftPackageIndex"),
                    "Support This Project"
                )
            )
        }

        func readmeSection() -> Node<HTML.BodyContext> {
            guard let readme = model.readme,
                  let html = try? MarkdownHTMLConverter.html(from: readme)
            else { return .empty }

            return .group(
                .article(
                    .class("readme"),
                    .attribute(named: "data-readme-base-url", value: model.readmeBaseUrl),
                    .raw(html)
                )
            )
        }
    }
}
