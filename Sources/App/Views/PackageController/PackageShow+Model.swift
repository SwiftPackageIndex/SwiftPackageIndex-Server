import Foundation
import Plot
import Vapor


extension PackageShow {
    
    struct Model: Equatable {
        var packageId: Package.Id
        var repositoryOwner: String
        var repositoryOwnerName: String
        var repositoryName: String
        var activity: Activity?
        var authors: [Link]?
        var swiftVersionBuildInfo: BuildInfo<SwiftVersionResults>?
        var platformBuildInfo: BuildInfo<PlatformResults>?
        var history: History?
        var languagePlatforms: LanguagePlatformInfo
        var license: License
        var licenseUrl: String?
        var products: ProductCounts?
        var releases: ReleaseInfo
        var stars: Int?
        var summary: String?
        var title: String
        var url: String
        var score: Int?
        var isArchived: Bool
        
        internal init(packageId: Package.Id,
                      repositoryOwner: String,
                      repositoryOwnerName: String,
                      repositoryName: String,
                      activity: Activity? = nil,
                      authors: [Link]? = nil,
                      swiftVersionBuildInfo: BuildInfo<SwiftVersionResults>? = nil,
                      platformBuildInfo: BuildInfo<PlatformResults>? = nil,
                      history: History? = nil,
                      languagePlatforms: LanguagePlatformInfo,
                      license: License,
                      licenseUrl: String? = nil,
                      products: ProductCounts? = nil,
                      releases: ReleaseInfo,
                      stars: Int? = nil,
                      summary: String?,
                      title: String,
                      url: String,
                      score: Int? = nil,
                      isArchived: Bool) {
            self.packageId = packageId
            self.repositoryOwner = repositoryOwner
            self.repositoryOwnerName = repositoryOwnerName
            self.repositoryName = repositoryName
            self.activity = activity
            self.authors = authors
            self.swiftVersionBuildInfo = swiftVersionBuildInfo
            self.platformBuildInfo = platformBuildInfo
            self.history = history
            self.languagePlatforms = languagePlatforms
            self.license = license
            self.licenseUrl = licenseUrl
            self.products = products
            self.releases = releases
            self.stars = stars
            self.summary = summary
            self.title = title
            self.url = url
            self.score = score
            self.isArchived = isArchived
        }
        
        init?(package: Package) {
            // we consider certain attributes as essential and return nil (raising .notFound)
            guard
                let repository = package.repository,
                let repositoryOwner = repository.owner,
                let repositoryOwnerName = repository.ownerDisplayName,
                let repositoryName = repository.name,
                let packageId = package.id
            else { return nil }

            self.init(
                packageId: packageId,
                repositoryOwner: repositoryOwner,
                repositoryOwnerName: repositoryOwnerName,
                repositoryName: repositoryName,
                activity: package.activity(),
                authors: package.authors(),
                swiftVersionBuildInfo: package.swiftVersionBuildInfo(),
                platformBuildInfo: package.platformBuildInfo(),
                history: package.history(),
                languagePlatforms: package.languagePlatformInfo(),
                license: package.repository?.license ?? .none,
                licenseUrl: package.repository?.licenseUrl,
                products: package.productCounts(),
                releases: package.releaseInfo(),
                stars: package.repository?.stars,
                summary: package.repository?.summary,
                title: package.name() ?? repositoryName,
                url: package.url,
                score: package.score,
                isArchived: package.repository?.isArchived ?? false
            )

        }
    }
    
}


extension PackageShow.Model {
    func licenseListItem() -> Node<HTML.ListContext> {
        let licenseDescription: Node<HTML.BodyContext> = {
            switch license.licenseKind {
                case .compatibleWithAppStore, .incompatibleWithAppStore:
                    return .group(
                        .unwrap(licenseUrl, {
                            .a(
                                .href($0),
                                .title(license.fullName),
                                .text(license.shortName)
                            )
                        }),
                        .text(" licensed")
                    )
                case .other:
                    return .unwrap(licenseUrl, {
                        .a(.href($0), .text(license.shortName))
                    })
                case .none:
                    return .span(
                        .class(license.licenseKind.cssClass),
                        .text(license.shortName)
                    )
            }
        }()

        let licenseClass: String = {
            switch license.licenseKind {
                case .compatibleWithAppStore:
                    return "license"
                case .incompatibleWithAppStore, .other:
                    return "license warning"
                case .none:
                    return "license error"
            }
        }()

        let moreInfoLink: Node<HTML.BodyContext> = {
            switch license.licenseKind {
                case .compatibleWithAppStore:
                    return .empty
                case .incompatibleWithAppStore:
                    return .a(
                        .id("license_more_info"),
                        .href(SiteURL.faq.relativeURL(anchor: "licenses")),
                        "Why might the \(license.shortName) be problematic?"
                    )
                case .other:
                    return .a(
                        .id("license_more_info"),
                        .href(SiteURL.faq.relativeURL(anchor: "licenses")),
                        "Why is this package's license unknown?"
                    )
                case .none:
                    return .a(
                        .id("license_more_info"),
                        .href(SiteURL.faq.relativeURL(anchor: "licenses")),
                        "Why should you not use unlicensed code?"
                    )
            }
        }()

        return .li(
            .class(licenseClass),
            licenseDescription,
            moreInfoLink
        )
    }

    func starsListItem() -> Node<HTML.ListContext> {
        guard let stars = stars,
              let str = Self.starsNumberFormatter.string(from: NSNumber(value: stars))
        else { return .empty }
        return .li(
            .class("stars"),
            .text("\(str) stars")
        )
    }

    func authorsListItem() -> Node<HTML.ListContext> {
        guard let authors = authors else { return .empty }
        let nodes = authors.map { Node<HTML.BodyContext>.a(.href($0.url), .text($0.label)) }
        return .li(
            .class("authors"),
            .group(listPhrase(opening: "By ", nodes: nodes, ifEmpty: "-", closing: "."))
        )
    }
    
    func historyListItem() -> Node<HTML.ListContext> {
        guard let history = history else { return .empty }

        let commitsLinkNode: Node<HTML.BodyContext> = .a(
            .href(history.commitCount.url),
            .text(history.commitCount.label)
        )

        let releasesLinkNode: Node<HTML.BodyContext> = .a(
            .href(history.releaseCount.url),
            .text(history.releaseCount.label)
        )

        var releasesSentenceFragments: [Node<HTML.BodyContext>] = []
        if isArchived {
            releasesSentenceFragments.append(contentsOf: [
                .strong("⚠️ No longer in active development."),
                " The package author has archived this project and the repository is read-only. It had ",
                commitsLinkNode, " and ", releasesLinkNode,
                " before being archived."
            ])
        } else {
            releasesSentenceFragments.append(contentsOf: [
                "In development for \(history.since), with ",
                commitsLinkNode, " and ", releasesLinkNode,
                "."
            ])
        }

        return .li(
            .class("history"),
            .group(releasesSentenceFragments)
        )
    }
    
    func activityListItem() -> Node<HTML.ListContext> {
        // Bail out if not at least one field is non-nil
        guard let activity = activity,
              activity.openIssues != nil
                || activity.openPullRequests != nil
                || activity.lastIssueClosedAt != nil
                || activity.lastPullRequestClosedAt != nil
        else { return .empty }
        
        let openItems = [activity.openIssues, activity.openPullRequests]
            .compactMap { $0 }
            .map { Node.a(.href($0.url), .text($0.label)) }
        
        let lastClosed: [Node<HTML.BodyContext>] = [
            activity.lastIssueClosedAt.map { .text("last issue was closed \($0)") },
            activity.lastPullRequestClosedAt.map { .text("last pull request was merged/closed \($0)") }
        ]
        .compactMap { $0 }
        
        return .li(
            .class("activity"),
            .group(listPhrase(opening: .text("There is ".pluralized(for: activity.openIssuesCount, plural: "There are ")), nodes: openItems, closing: ". ") + listPhrase(opening: "The ", nodes: lastClosed, conjunction: " and the ", closing: "."))
        )
    }

    func librariesListItem() -> Node<HTML.ListContext> {
        guard let products = products
        else { return .empty }

        return .li(
            .class("libraries"),
            .text(pluralizedCount(products.libraries, singular: "library", plural: "libraries", capitalized: true))
        )
    }

    func executablesListItem() -> Node<HTML.ListContext> {
        guard let products = products
        else { return .empty }

        return .li(
            .class("executables"),
            .text(pluralizedCount(products.executables, singular: "executable", capitalized: true))
        )
    }

    static var starsNumberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.thousandSeparator = ","
        f.numberStyle = .decimal
        return f
    }()
    
    func stableReleaseMetadata() -> Node<HTML.ListContext> {
        guard let datedLink = releases.stable else { return .empty }
        return releaseMetadata(datedLink, title: "Latest Stable Release", cssClass: "stable")
    }

    func betaReleaseMetadata() -> Node<HTML.ListContext> {
        guard let datedLink = releases.beta else { return .empty }
        return releaseMetadata(datedLink, title: "Latest Beta Release", cssClass: "beta")
    }
    
    func defaultBranchMetadata() -> Node<HTML.ListContext> {
        guard let datedLink = releases.latest else { return .empty }
        return releaseMetadata(datedLink, title: "Default Branch", datePrefix: "Modified", cssClass: "branch")
    }
    
    func releaseMetadata(_ datedLink: DatedLink, title: String, datePrefix: String = "Released", cssClass: String) -> Node<HTML.ListContext> {
        .li(
            .class(cssClass),
            .a(
                .href(datedLink.link.url),
                .span(
                    .class(cssClass),
                    .text(datedLink.link.label)
                )
            ),
            .strong(.text(title)),
            .small(.text([datePrefix, datedLink.date].joined(separator: " ")))
        )
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
        return .ul(
            .class("matrix compatibility"),
            .forEach(rows) { compatibilityListItem(label: $0.label, cells: $0.results.cells) }
        )
    }

    func platformCompatibilitySection() -> Node<HTML.BodyContext> {
        guard let buildInfo = platformBuildInfo else { return .empty }
        let rows = Self.groupBuildInfo(buildInfo)
        return .ul(
            .class("matrix compatibility"),
            .forEach(rows) { compatibilityListItem(label: $0.label, cells: $0.results.cells) }
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
}


// MARK: - General helpers

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

extension License.Kind {
    var cssClass: String {
        switch self {
            case .none: return "no_license"
            case .incompatibleWithAppStore, .other: return "incompatible_license"
            case .compatibleWithAppStore: return "compatible_license"
        }
    }

    var iconName: String {
        switch self {
            case .compatibleWithAppStore: return "osi"
            case .incompatibleWithAppStore, .other, .none: return "warning"
        }
    }
}
