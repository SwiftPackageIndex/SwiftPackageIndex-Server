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
                        .comment(model.score.map(String.init) ?? "unknown"),
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
            let row = BuildStatusRow(references: [.init(name: "5.2.3", kind: .stable),
                                                  .init(name: "main", kind: .branch)],
                                     results: [
                                        .init(swiftVersion: .v4_2, status: .failed),
                                        .init(swiftVersion: .v5_0, status: .failed),
                                        .init(swiftVersion: .v5_1, status: .unknown),
                                        .init(swiftVersion: .v5_2, status: .success),
                                        .init(swiftVersion: .v5_3, status: .success)
                                    ])
            return .if(environment != .production, .section(
                .class("swift"),
                .h3("Swift Version Compatibility"),
                .ul(
                    swiftVersionCompatibilityListItem(row),
                    swiftVersionCompatibilityListItem(row)
                )
            ))
        }

        final func swiftVersionCompatibilityListItem(_ row: BuildStatusRow) -> Node<HTML.ListContext> {
            let results: [BuildResult] = row.results
                .sorted { $0.swiftVersion < $1.swiftVersion }.reversed()
            return .li(
                .class("reference"),
                row.label,
                // Implementation note: The compatibility section should include *both* the Swift labels, and the status boxes on *every* row. They are removed in desktop mode via CSS.
                .div(
                    .class("compatibility"),
                    .div(
                        .class("swift_versions"),
                        .forEach(results) { $0.headerNode }
                    ),
                    .div(
                        .class("build_statuses"),
                        .forEach(results) { $0.cellNode }
                    )
                )
            )
        }
    }
}


extension PackageShow.View {
    struct SwiftVersion: Equatable, Hashable, Comparable {
        static func < (lhs: SwiftVersion, rhs: SwiftVersion) -> Bool {
            lhs.displayName < rhs.displayName
        }
        
        var displayName: String
        var isLatest: Bool
        var isBeta: Bool
        var note: String? {
            if isLatest { return "latest" }
            if isBeta { return "beta" }
            return nil
        }
        
        static let v4_2: Self = .init(displayName: "4.2", isLatest: false, isBeta: false)
        static let v5_0: Self = .init(displayName: "5.0", isLatest: false, isBeta: false)
        static let v5_1: Self = .init(displayName: "5.1", isLatest: false, isBeta: false)
        static let v5_2: Self = .init(displayName: "5.2", isLatest: true, isBeta: false)
        static let v5_3: Self = .init(displayName: "5.3", isLatest: false, isBeta: true)
        
        static let all: [Self] = [v4_2, v5_0, v5_1, v5_2, v5_3]
    }

    struct Reference: Equatable {
        var name: String
        var kind: Kind
        
        enum Kind: String {
            case beta
            case branch
            case stable
        }
        
        var node: Node<HTML.BodyContext> {
            .span(
                .class("\(kind)"),
                .i(.class("icon \(kind)")),
                .text(name)
            )
        }
    }
    
    struct BuildStatusRow {
        var references: [Reference]
        var results: [BuildResult]
        
        var label: Node<HTML.BodyContext> {
            guard !references.isEmpty else { return .empty }
            return .div(
                .class("label"),
                .div( // Note: It may look like there is a completely useless div here, but it's needed. I promise.
                    .div(
                        .group(references.map(\.node).joined(separator: .text(" and ")))
                    )
                )
            )
        }
    }
    
    struct BuildResult: Equatable {
        var swiftVersion: SwiftVersion
        var status: Status
        
        enum Status: String, Equatable {
            case success
            case failed
            case unknown
        }
        
        var headerNode: Node<HTML.BodyContext> {
            .div(
                .text(swiftVersion.displayName),
                .unwrap(swiftVersion.note) { .element(named: "small", text: "(\($0))") }
            )
        }
        
        var cellNode: Node<HTML.BodyContext> {
            .div(
                .class("\(status)"),
                .attribute(named: "title", value: title),
                .i(.class("icon build_\(status)"))
            )
        }
        
        var title: String {
            switch status {
                case .success:
                    return "Built successfully with Swift \(swiftVersion.displayName)"
                case .failed:
                    return "Build failed with Swift \(swiftVersion.displayName)"
                case .unknown:
                    return "No build information available for Swift \(swiftVersion.displayName)"
            }
        }
    }
}


extension Array where Element == Node<HTML.BodyContext> {
    func joined(separator: Node<HTML.BodyContext>) -> [Node<HTML.BodyContext>] {
        guard let first = first else { return [] }
        return dropFirst().reduce([first]) { $0 + [separator, $1] }
    }
}
