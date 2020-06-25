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
            "\(model.title) on the Swift Package Index – \(model.summary)"
        }

        override func bodyClass() -> String? {
            "package"
        }

        override func content() -> Node<HTML.BodyContext> {
            .group(
                .div(
                    .class("split"),
                    .div(
                        .h2(.text(model.title)),
                        .element(named: "small", nodes: [ // TODO: Fix after Plot update
                            .a(
                                .id("package_url"),
                                .href(model.url),
                                .text(model.url)
                            )
                        ])
                    ),
                    licenseLozenge()
                ),
                .hr(),
                .p(
                    .class("description"),
                    .text(model.summary)
                ),
                .section(
                    .class("metadata"),
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
                        },
                        .unwrap(model.starsClause()) {
                            .li(.class("icon stars"), $0)
                        }
                    )
                ),
                .element(named: "hr", nodes:[ // TODO: Fix after Plot update
                    .attribute(named: "class", value: "short")
                ]),
                .section(
                    .class("releases"),
                    .ul(
                        .li(.group(model.stableReleaseClause())),
                        .li(.group(model.betaReleaseClause())),
                        .li(.group(model.latestReleaseClause()))
                    )
                ),
                swiftVersionCompatibilitySection(),
                .section(
                    .class("language_platforms"),
                    .h3("Language and Platforms"),
                    .unwrap(model.languagesAndPlatformsClause(), { .ul(.group($0)) },
                            else: .p(
                                .text("The manifest for this package doesn't include metadata on which versions of Swift, and which platforms it supports – Are you the package author? "),
                                .a(
                                    .href(SiteURL.faq.relativeURL(anchor: "language-and-platforms")),
                                    .text("Learn how to fix this")
                                ),
                                .text(".")
                            )
                    )
                )
            )
        }

        func licenseLozenge() -> Node<HTML.BodyContext> {
            switch model.license.licenseKind {
                case .compatibleWithAppStore:
                    return .div(
                        .class("license"),
                        .attribute(named: "title", value: model.license.fullName), // TODO: Fix after Plot update
                        .i(.class("icon osi")),
                        .text(model.license.shortName)
                    )
                case .noneOrUnknown,
                     .incompatibleWithAppStore:
                    return .a(
                        .href(SiteURL.faq.relativeURL(anchor: "license-problems")),
                        .div(
                            .class("license \(model.license.licenseKind.rawValue)"),
                            .attribute(named: "title", value: model.license.fullName), // TODO: Fix after Plot update
                            .i(.class("icon warning")),
                            .text(model.license.shortName)
                        )
                    )
            }
        }

        final func swiftVersionCompatibilitySection() -> Node<HTML.BodyContext> {
            let environment = (try? Environment.detect()) ?? .development
            return .if(environment != .production, .section(
                .class("swift"),
                .h3("Swift Version Compatibility"),
                .ul(
                    // Implementation note: Include one row here for every grouped set of references
                    swiftVersionCompatibilityListItem(),
                    swiftVersionCompatibilityListItem()
                )
            ))
        }

        final func swiftVersionCompatibilityListItem() -> Node<HTML.ListContext> {
            .li(
                .class("reference"),
                .div(
                    .class("label"),
                    .div( // Note: It may look like there is a completely useless div here, but it's needed. I promise.
                        .div(
                            .span(
                                .class("stable"),
                                .i(.class("icon stable")),
                                "5.2.3"
                            ),
                            " and ",
                            .span(
                                .class("branch"),
                                .i(.class("icon branch")),
                                "main"
                            )
                        )
                    )
                ),
                // Implementation note: The compatibility section should include *both* the Swift labels, and the status boxes on *every* row. They are removed in desktop mode via CSS.
                .div(
                    .class("compatibility"),
                    .div(
                        .class("swift_versions"),
                        .div(
                            "5.3",
                            .element(named: "small", text: "(beta)")
                        ),
                        .div(
                            "5.2",
                            .element(named: "small", text: "(latest)")
                        ),
                        .div("5.1"),
                        .div("5.0"),
                        .div("4.2")
                    ),
                    .div(
                        .class("build_statuses"),
                        .div(
                            .class("success"),
                            .i(.class("icon build_success"))
                        ),
                        .div(
                            .class("success"),
                            .i(.class("icon build_success"))
                        ),
                        .div(
                            .class("unknown"),
                            .i(.class("icon build_unknown"))
                        ),
                        .div(
                            .class("failed"),
                            .i(.class("icon build_failed"))
                        ),
                        .div(
                            .class("failed"),
                            .i(.class("icon build_failed"))
                        )
                    )
                )
            )
        }
    }
}
