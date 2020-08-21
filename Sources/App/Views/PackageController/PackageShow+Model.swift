import Foundation
import Plot
import Vapor


extension PackageShow {
    
    struct Model: Equatable {
        var packageId: Package.Id
        var repositoryOwner: String
        var repositoryName: String
        var activity: Activity?
        var authors: [Link]?
        var swiftVersionBuildInfo: BuildInfo<SwiftVersionResults>?
        var platformBuildInfo: BuildInfo<PlatformResults>?
        var history: History?
        var languagePlatforms: LanguagePlatformInfo
        var license: License
        var products: ProductCounts?
        var releases: ReleaseInfo
        var stars: Int?
        var summary: String?
        var title: String
        var url: String
        var score: Int?
        
        internal init(packageId: Package.Id,
                      repositoryOwner: String,
                      repositoryName: String,
                      activity: Activity? = nil,
                      authors: [Link]? = nil,
                      swiftVersionBuildInfo: BuildInfo<SwiftVersionResults>? = nil,
                      platformBuildInfo: BuildInfo<PlatformResults>? = nil,
                      history: History? = nil,
                      languagePlatforms: LanguagePlatformInfo,
                      license: License,
                      products: ProductCounts? = nil,
                      releases: ReleaseInfo,
                      stars: Int? = nil,
                      summary: String?,
                      title: String,
                      url: String,
                      score: Int? = nil) {
            self.packageId = packageId
            self.repositoryOwner = repositoryOwner
            self.repositoryName = repositoryName
            self.activity = activity
            self.authors = authors
            self.swiftVersionBuildInfo = swiftVersionBuildInfo
            self.platformBuildInfo = platformBuildInfo
            self.history = history
            self.languagePlatforms = languagePlatforms
            self.license = license
            self.products = products
            self.releases = releases
            self.stars = stars
            self.summary = summary
            self.title = title
            self.url = url
            self.score = score
        }
        
        init?(package: Package) {
            // we consider certain attributes as essential and return nil (raising .notFound)
            guard let title = package.name() else { return nil }

            guard
                let repository = package.repository,
                let repositoryOwner = repository.owner,
                let repositoryName = repository.name,
                let packageId = package.id
            else { return nil }

            self.init(
                packageId: packageId,
                repositoryOwner: repositoryOwner,
                repositoryName: repositoryName,
                activity: package.activity(),
                authors: package.authors(),
                swiftVersionBuildInfo: package.swiftVersionBuildInfo(),
                platformBuildInfo: package.platformBuildInfo(),
                history: package.history(),
                languagePlatforms: package.languagePlatformInfo(),
                license: package.repository?.license ?? .none,
                products: package.productCounts(),
                releases: package.releaseInfo(),
                stars: package.repository?.stars,
                summary: package.repository?.summary,
                title: title,
                url: package.url,
                score: package.score
            )

        }
    }
    
}


extension PackageShow.Model {
    func authorsClause() -> Node<HTML.BodyContext>? {
        guard let authors = authors else { return nil }
        let nodes = authors.map { Node<HTML.BodyContext>.a(.href($0.url), .text($0.label)) }
        return .group(Self.listPhrase(opening: "By ",
                                      nodes: nodes,
                                      ifNoValues: "-",
                                      closing: "."))
    }
    
    func historyClause() -> Node<HTML.BodyContext>? {
        guard let history = history else { return nil }
        return .group([
            "In development for \(history.since), with ",
            .a(
                .href(history.commitCount.url),
                .text(history.commitCount.label)
            ),
            " and ",
            .a(
                .href(history.releaseCount.url),
                .text(history.releaseCount.label)
            ),
            "."
        ])
    }
    
    func activityClause() -> Node<HTML.BodyContext>? {
        guard
            let activity = activity,
            // bail out if not at least one field is non-nil
            activity.openIssues != nil
                || activity.openPullRequests != nil
                || activity.lastIssueClosedAt != nil
                || activity.lastPullRequestClosedAt != nil
        else { return nil }
        
        let openItems = [activity.openIssues, activity.openPullRequests]
            .compactMap { $0 }
            .map { Node<HTML.BodyContext>.a(.href($0.url), .text($0.label)) }
        
        let lastClosed: [Node<HTML.BodyContext>] = [
            activity.lastIssueClosedAt.map { .text("last issue was closed \($0)") },
            activity.lastPullRequestClosedAt.map { .text("last pull request was merged/closed \($0)") }
        ]
        .compactMap { $0 }
        
        return .group(
            Self.listPhrase(opening: .text("There is ".pluralized(for: activity.openIssuesCount,
                                                                  plural: "There are ")),
                            nodes: openItems, closing: ". ") +
                Self.listPhrase(opening: "The ", nodes: lastClosed, conjunction: " and the ", closing: ".")
        )
    }
    
    func productsClause() -> Node<HTML.BodyContext>? {
        guard let products = products else { return nil }
        return .group([
            "\(title) contains ",
            .strong(
                .text(pluralizedCount(products.libraries, singular: "library", plural: "libraries"))
            ),
            " and ",
            .strong(
                .text(pluralizedCount(products.executables, singular: "executable"))
            ),
            "."
        ])
    }
    
    static var starsNumberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.thousandSeparator = ","
        f.numberStyle = .decimal
        return f
    }()
    
    func starsClause() -> Node<HTML.BodyContext>? {
        guard
            let stars = stars,
            let str = Self.starsNumberFormatter.string(from: NSNumber(value: stars))
        else { return nil }
        return .group(
            "\(str) stars."
        )
    }
    
    func stableReleaseClause() -> [Node<HTML.BodyContext>] {
        releases.stable.map { datedLink -> [Node<HTML.BodyContext>] in
            [
                "The latest stable release is ",
                .a(
                    .href(datedLink.link.url),
                    .span(
                        .class("stable"),
                        .i(.class("icon stable")),
                        .text(datedLink.link.label)
                    )
                ),
                ". Released \(datedLink.date)."
            ]
        } ?? []
    }
    
    func betaReleaseClause() -> [Node<HTML.BodyContext>] {
        releases.beta.map { datedLink -> [Node<HTML.BodyContext>] in
            [
                "The latest beta release is ",
                .a(
                    .href(datedLink.link.url),
                    .span(
                        .class("beta"),
                        .i(.class("icon beta")),
                        .text(datedLink.link.label)
                    )
                ),
                ". Released \(datedLink.date)."
            ]
        } ?? []
    }
    
    func latestReleaseClause() -> [Node<HTML.BodyContext>] {
        releases.latest.map { datedLink -> [Node<HTML.BodyContext>] in
            [
                "The last commit to ",
                .a(
                    .href(datedLink.link.url),
                    .span(
                        .class("branch"),
                        .i(.class("icon branch")),
                        .text(datedLink.link.label)
                    )
                ),
                " was \(datedLink.date)."
            ]
        } ?? []
    }
    
    func languagesAndPlatformsClause() -> Node<HTML.ListContext>? {
        let groups = Self.lpInfoGroups(languagePlatforms)
        let listItems = groups
            .compactMap { Self.lpInfoSection(keypaths: $0, languagePlatforms: languagePlatforms) }
            .map { Node<HTML.ListContext>.li($0) }
        guard !listItems.isEmpty else { return nil }
        return .group(listItems)
    }
    
    typealias LanguagePlatformKeyPath = KeyPath<LanguagePlatformInfo, Version?>
    
    static func lpInfoGroups(_ lpInfo: LanguagePlatformInfo) -> [[LanguagePlatformKeyPath]] {
        let allKeyPaths: [LanguagePlatformKeyPath] = [\.stable, \.beta, \.latest]
        var availableKeyPaths = allKeyPaths
        let groups = allKeyPaths.map { kp -> [LanguagePlatformKeyPath] in
            guard let v = lpInfo[keyPath: kp] else { return [] }
            let group = availableKeyPaths.filter {
                lpInfo[keyPath: $0]?.platforms == v.platforms
                    && lpInfo[keyPath: $0]?.swiftVersions == v.swiftVersions }
            availableKeyPaths.removeAll(where: { group.contains($0) })
            return group
        }
        .filter { !$0.isEmpty }
        return groups
    }
    
    static func lpInfoSection(keypaths: [LanguagePlatformKeyPath],
                              languagePlatforms: LanguagePlatformInfo) -> Node<HTML.BodyContext>? {
        guard let leadingKeyPath = keypaths.first else { return nil }
        let cssClasses: [LanguagePlatformKeyPath: String] = [\.stable: "stable",
                                                             \.beta: "beta",
                                                             \.latest: "branch"]
        let nodes = keypaths.compactMap { kp -> Node<HTML.BodyContext>? in
            guard let info = languagePlatforms[keyPath: kp] else { return nil }
            let cssClass = cssClasses[kp]!
            return .a(
                .href(info.link.url),
                .span(
                    .class(cssClass),
                    .i(.class("icon \(cssClass)")),
                    .text(info.link.label)
                )
            )
        }
        
        // swift versions and platforms are the same for all versions because we grouped them,
        // so we use the leading keypath to obtain it
        guard
            let versionInfo = languagePlatforms[keyPath: leadingKeyPath],
            // at least one group must be non-empty - or else we return nil and collapse the group
            !(versionInfo.swiftVersions.isEmpty && versionInfo.platforms.isEmpty)
        else { return nil }
        
        return .group([
            .p(
                .group(Self.listPhrase(opening: .text("Version".pluralized(for: keypaths.count) + " "),
                                       nodes: nodes)),
                " \("supports".pluralized(for: keypaths.count, plural: "support")):"
            ),
            .ul(
                .group([
                    versionsClause(versionInfo.swiftVersions),
                    platformsClause(versionInfo.platforms)
                ]
                .filter { !$0.isEmpty }
                .map { .li(.group($0)) }
                )
            )
        ])
    }
    
    static func versionsClause(_ versions: [String]) -> [Node<HTML.BodyContext>] {
        let nodes = versions.map { Node<HTML.BodyContext>.strong(.text($0)) }
        return Self.listPhrase(opening: "Swift ", nodes: nodes)
    }
    
    static func platformsClause(_ platforms: [Platform]) -> [Node<HTML.BodyContext>] {
        let nodes = platforms
            .sorted(by: { $0.ordinal < $1.ordinal })
            .map { "\($0)+" }
            .map { Node<HTML.BodyContext>.strong(.text($0)) }
        return Self.listPhrase(opening: "", nodes: nodes, closing: ".")
    }
    
    static func groupBuildInfo<T>(_ buildInfo: BuildInfo<T>) -> [BuildStatusRow<T>] {
        let allKeyPaths: [KeyPath<BuildInfo<T>, NamedBuildResults<T>?>] = [\.stable, \.beta, \.latest]
        var availableKeyPaths = allKeyPaths
        let groups = allKeyPaths.map { kp -> [KeyPath<BuildInfo<T>, NamedBuildResults<T>?>] in
            guard let r = buildInfo[keyPath: kp] else { return [] }
            let group = availableKeyPaths.filter { buildInfo[keyPath: $0]?.results == r.results }
            availableKeyPaths.removeAll(where: { group.contains($0) })
            return group
        }
        let rows = groups.compactMap { keyPaths -> BuildStatusRow<T>? in
            guard let first = keyPaths.first,
                  let results = buildInfo[keyPath: first]?.results else { return nil }
            let references = keyPaths.compactMap { kp -> Reference? in
                guard let name = buildInfo[keyPath: kp]?.referenceName else { return nil }
                switch kp {
                    case \.stable:
                        return .init(name: name, kind: .release)
                    case \.beta:
                        return .init(name: name, kind: .preRelease)
                    case \.latest:
                        return .init(name: name, kind: .defaultBranch)
                    default:
                        return nil
                }
            }
            return .init(references: references, results: results)
        }
        return rows
    }

    func swiftVersionCompatibilitySection() -> Node<HTML.BodyContext> {
        guard let buildInfo = swiftVersionBuildInfo else { return .empty }
        let rows = Self.groupBuildInfo(buildInfo)
        return .section(
            .h3("Swift Version Compatibility"),
            .ul(
                .class("matrix"),
                .forEach(rows) { compatibilityListItem(label: $0.label, cells: $0.results.cells) }
            ),
            .div(
                .class("right"),
                .div(
                    .id("swift_version_badge"),
                    .text(badgeMarkdown(for: .swiftVersions)),
                    .attribute(named: "hidden")
                ),
                .div(
                    .a(
                        .href(SiteURL.package(.value(repositoryOwner), .value(repositoryName), .builds).relativeURL()),
                        "Full build results"
                    )
                )
            )
        )
    }

    func platformCompatibilitySection() -> Node<HTML.BodyContext> {
        guard let buildInfo = platformBuildInfo else { return .empty }
        let rows = Self.groupBuildInfo(buildInfo)
        return .section(
            .h3("Platform Compatibility"),
            .ul(
                .class("matrix"),
                .forEach(rows) { compatibilityListItem(label: $0.label, cells: $0.results.cells) }
            ),
            .div(
                .class("right"),
                .div(
                    .id("platform_badge"),
                    .text(badgeMarkdown(for: .platforms)),
                    .attribute(named: "hidden")
                ),
                .div(
                    .a(
                        .href(SiteURL.package(.value(repositoryOwner), .value(repositoryName), .builds).relativeURL()),
                        "Full build results"
                    )
                )
            )
        )
    }

    func compatibilityListItem<T>(label: Node<HTML.BodyContext>,
                                  cells: [BuildResult<T>]) -> Node<HTML.ListContext> {
        return .li(
            .class("row"),
            label,
            .div(
                // Matrix CSS should include *both* the column labels, and the column values status boxes in *every* row.
                .class("row_values"),
                .div(
                    .class("column_label"),
                    .forEach(cells) { $0.headerNode }
                ),
                .div(
                    .class("result"),
                    .forEach(cells) { $0.cellNode }
                )
            )
        )
    }


    func badgeURL(for type: Package.BadgeType) -> String {
        let cs = CharacterSet.urlHostAllowed.subtracting(.init(charactersIn: "=:"))
        let url = SiteURL.api(.packages(.value(repositoryOwner), .value(repositoryName), .badge)).absoluteURL(parameters: ["type": type.rawValue])
        let escaped = url.addingPercentEncoding(withAllowedCharacters: cs)
            ?? url
        return "https://img.shields.io/endpoint?url=\(escaped)"
    }


    func badgeMarkdown(for type: Package.BadgeType) -> String {
        let spiPackageURL = SiteURL.package(.value(repositoryOwner), .value(repositoryName), .none)
            .absoluteURL()
        return "[![](\(badgeURL(for: type)))](\(spiPackageURL))"
    }

}


// MARK: - General helpers

extension PackageShow.Model {
    
    static func listPhrase(opening: Node<HTML.BodyContext>,
                           nodes: [Node<HTML.BodyContext>],
                           ifNoValues: Node<HTML.BodyContext>? = nil,
                           conjunction: Node<HTML.BodyContext> = " and ",
                           closing: Node<HTML.BodyContext> = "") -> [Node<HTML.BodyContext>] {
        switch nodes.count {
            case 0:
                return ifNoValues.map { [$0] } ?? []
            case 1:
                return [opening, nodes[0], closing]
            case 2:
                return [opening, nodes[0], conjunction, nodes[1], closing]
            default:
                let start: [Node<HTML.BodyContext>]
                    = [opening, nodes.first!]
                let middle: [[Node<HTML.BodyContext>]] = nodes[1..<(nodes.count - 1)].map {
                    [", ", $0]
                }
                let end: [Node<HTML.BodyContext>] =
                    [", and ", nodes.last!, closing]
                return middle.reduce(start) { $0 + $1 } + end
        }
    }
    
}


extension Platform {
    var ordinal: Int {
        switch name {
            case .ios:
                return 0
            case .macos:
                return 1
            case .watchos:
                return 2
            case .tvos:
                return 3
        }
    }
}
