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
                    .unwrap(model.authorsClause()) {
                        .li(.class("icon author"), $0)
                    },
                    .unwrap(model.historyClause()) {
                        .li(.class("icon history"), $0)
                    },
                    .unwrap(model.activityClause()) {
                        .li(.class("icon activity"), $0)
                    },
                    .unwrap(model.productsClause()) {
                        .li(.class("icon products"), $0)
                    }
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
                sidebarReleases()
            )
        }

        func sidebarLinks() -> Node<HTML.BodyContext> {
            .section(
                .class("sidebar_links"),
                sidebarLinksList(),
                .hr(),
                sidebarMetadataList()
            )
        }

        func sidebarLinksList() -> Node<HTML.BodyContext> {
            .ul(
                .class("package_links"),
                .li(
                    .a(
                        .href(model.url),
                        // TODO: Make "GitHub" dynamic.
                        "View on GitHub"
                    )
                ),
                .li(
                    .a(
                        .href(SiteURL.package(.value(model.repositoryOwner), .value(model.repositoryName), .builds).relativeURL()),
                        "Package Compatibility"
                    )
                )
            )
        }

        func sidebarMetadataList() -> Node<HTML.BodyContext> {
            .ul(
                .unwrap(model.starsClause()) {
                    .li(.class("icon stars"), $0)
                },
                licenseMetadata()
            )
        }

        func sidebarReleases() -> Node<HTML.BodyContext> {
            .section(
                .class("sidebar_releases"),
                .h3("Releases"),
                .ul(
                    model.stableReleaseMetadata(),
                    model.betaReleaseMetadata(),
                    model.defaultBranchMetadata()
                )
            )
        }

        func licenseMetadata() -> Node<HTML.ListContext> {
            let licenseDiv: Node<HTML.BodyContext> = .div(
                .attribute(named: "title", value: model.license.fullName),
                .text(model.license.shortName)
            )

            let whatsThisLink: Node<HTML.BodyContext> = {
                switch model.license.licenseKind {
                    case .compatibleWithAppStore:
                        return .empty
                    case .incompatibleWithAppStore, .other, .none:
                        return .small(
                            .a(
                                .href(SiteURL.faq.relativeURL(anchor: "licenses")),
                                "Why is this icon not green?"
                            )
                        )
                }
            }()

            return .li(
                .class("icon \(model.license.licenseKind.iconName) \(model.license.licenseKind.cssClass)"),
                .unwrap(model.licenseUrl, { .a(href: $0, licenseDiv) }, else: licenseDiv),
                whatsThisLink
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


private extension License.Kind {
    var cssClass: String {
        switch self {
            case .none: return "red"
            case .incompatibleWithAppStore, .other: return "orange"
            case .compatibleWithAppStore: return "green"
        }
    }

    var iconName: String {
        switch self {
            case .compatibleWithAppStore: return "osi"
            case .incompatibleWithAppStore, .other, .none: return "warning"
        }
    }
}
