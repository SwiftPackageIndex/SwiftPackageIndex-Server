import Plot


extension PackageShow {
    struct Model: Equatable {
        var title: String
        var url: String
        var license: License
        var summary: String
        var authors: [Link]?
        var history: History?
        var activity: Activity?
        var products: ProductCounts?
        var releases: ReleaseInfo
        var languagePlatforms: LanguagePlatformInfo

        struct History: Equatable {
            var since: String
            var commitCount: Link
            var releaseCount: Link
        }

        struct Activity: Equatable {
            var openIssues: Link
            var pullRequests: Link
            var lastPullRequestClosedMerged: String
        }

        struct ProductCounts: Equatable {
            var libraries: Int
            var executables: Int
        }

        struct ReleaseInfo: Equatable {
            var stable: DatedLink?
            var beta: DatedLink?
            var latest: DatedLink?
        }

        struct Version: Equatable {
            var link: Link
            var swiftVersions: [String]
            var platforms: [Platform]
        }

        struct LanguagePlatformInfo: Equatable {
            var stable: Version?
            var beta: Version?
            var latest: Version?
        }
    }
}


extension PackageShow.Model {
    func authorsClause() -> Node<HTML.BodyContext>? {
        guard let authors = authors else { return nil }
        let nodes = authors.map { Node<HTML.BodyContext>.a(.href($0.url), .text($0.label)) }
        return .group(Self.listPhrase(opening: .text("By "),
                                      nodes: nodes,
                                      ifNoValues: ["-"]))
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
        guard let activity = activity else { return nil }
        return .group([
            "There are ",
            .a(
                .href(activity.openIssues.url),
                .text(activity.openIssues.label)
            ),
            ", and ",
            .a(
                .href(activity.pullRequests.url),
                .text(activity.pullRequests.label)
            ),
            ". The last pull request was closed/merged \(activity.lastPullRequestClosedMerged)."
        ])
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
            .compactMap(lpInfoSection(for:))
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

    func lpInfoSection(for keypaths: [LanguagePlatformKeyPath]) -> Node<HTML.BodyContext>? {
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

        // swift versions and platforms are the same all versions because we grouped them,
        // so we use the leading keypath to obtain it
        guard let versionInfo = languagePlatforms[keyPath: leadingKeyPath] else { return nil }

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

    func versionsClause(_ versions: [String]) -> [Node<HTML.BodyContext>] {
        let nodes = versions.map { Node<HTML.BodyContext>.strong(.text($0)) }
        return Self.listPhrase(opening: .text("Swift "), nodes: nodes)
    }

    func platformsClause(_ platforms: [Platform]) -> [Node<HTML.BodyContext>] {
        let nodes = platforms
            .sorted(by: { $0.ordinal < $1.ordinal })
            .map { "\($0)+" }
            .map { Node<HTML.BodyContext>.strong(.text($0)) }
        return Self.listPhrase(opening: .text(""), nodes: nodes)
    }

}


// MARK: - General helpers

extension PackageShow.Model {

    static func listPhrase(opening: Node<HTML.BodyContext>,
                           nodes: [Node<HTML.BodyContext>],
                           ifNoValues: [Node<HTML.BodyContext>] = []) -> [Node<HTML.BodyContext>] {
        switch nodes.count {
            case 0:
                return ifNoValues
            case 1:
                return [opening, nodes[0]]
            case 2:
                return [opening, nodes[0], " and ", nodes[1]]
            default:
                let start: [Node<HTML.BodyContext>]
                    = [opening, nodes.first!]
                let middle: [[Node<HTML.BodyContext>]] = nodes[1..<(nodes.count - 1)].map {
                    [", ", $0]
                }
                let end: [Node<HTML.BodyContext>] =
                    [", and ", nodes.last!, "."]
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
