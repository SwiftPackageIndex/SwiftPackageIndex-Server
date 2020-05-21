import Plot


extension PackageShow {
    struct Model: Equatable {
        let title: String
        let url: String
        let license: License
        let summary: String
        let authors: [Link]
        let history: History?
        let activity: Activity?
        let products: ProductCounts?
        let releases: ReleaseInfo
        let languagePlatforms: LanguagePlatformInfo

        struct Link: Equatable {
            let name: String
            let url: String
        }

        struct DatedLink: Equatable {
            let date: String   // FIXME: use RelativeDateTimeFormatter
            let link: Link
        }

        struct History: Equatable {
            let since: String  // FIXME: use RelativeDateTimeFormatter
            let commits: Link
            let releases: Link
        }

        struct Activity: Equatable {
            let openIssues: Link
            let pullRequests: Link
            let lastPullRequestClosedMerged: String
        }

        struct ProductCounts: Equatable {
            let libraries: Int
            let executables: Int
        }

        struct ReleaseInfo: Equatable {
            let stable: DatedLink?
            let beta: DatedLink?
            let latest: DatedLink?
        }

        struct Version: Equatable {
            let link: Link
            let swiftVersions: [String]
            let platforms: [Platform]
        }

        struct LanguagePlatformInfo: Equatable {
            let stable: Version
            let beta: Version
            let latest: Version
        }
    }
}


extension PackageShow.Model {
    func authorsClause() -> [Node<HTML.BodyContext>] {
        let nodes = authors.map { Node<HTML.BodyContext>.a(.href($0.url), .text($0.name)) }
        return Self.listPhrase(opening: .text("By "),
                               nodes: nodes,
                               ifNoValues: ["-"])
    }

    func historyClause() -> [Node<HTML.BodyContext>] {
        guard let history = history else { return [] }
        return [
            "In development for \(history.since), with ",
            .a(
                .href(history.commits.url),
                .text(history.commits.name)
            ),
            " and ",
            .a(
                .href(history.releases.url),
                .text(history.releases.name)
            ),
            "."
        ]
    }

    func activityClause() -> [Node<HTML.BodyContext>] {
        guard let activity = activity else { return [] }
        return [
            "There are ",
            .a(
                .href(activity.openIssues.url),
                .text(activity.openIssues.name)
            ),
            ", and ",
            .a(
                .href(activity.pullRequests.url),
                .text(activity.pullRequests.name)
            ),
            ". The last pull request was closed/merged \(activity.lastPullRequestClosedMerged)."
        ]
    }

    func productsClause() -> [Node<HTML.BodyContext>] {
        guard let products = products else { return [] }
        return [
            "\(title) contains ",
            .strong(
                .text(pluralizedCount(products.libraries, singular: "library", plural: "libraries"))
            ),
            " and ",
            .strong(
                .text(pluralizedCount(products.executables, singular: "executable"))
            ),
            "."
        ]
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
                        .text(datedLink.link.name)
                    )
                ),
                ". Released \(datedLink.date) ago."  // FIXME: turn into relative date
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
                        .text(datedLink.link.name)
                    )
                ),
                ". Released \(datedLink.date) ago."  // FIXME: turn into relative date
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
                        .text(datedLink.link.name)
                    )
                ),
                " was \(datedLink.date) ago."  // FIXME: turn into relative date
            ]
        } ?? []
    }

    func languagesAndPlatformsClause() -> [Node<HTML.ListContext>] {
        let groups = Self.lpInfoGroups(languagePlatforms)
        return groups.map {
            .li(.group(lpInfoSection(for: $0)))
        }
    }

    typealias LanguagePlatformKeyPath = KeyPath<LanguagePlatformInfo, Version>

    static func lpInfoGroups(_ lpInfo: LanguagePlatformInfo) -> [[LanguagePlatformKeyPath]] {
        let allKeyPaths: [LanguagePlatformKeyPath] = [\.stable, \.beta, \.latest]
        var availableKeyPaths = allKeyPaths
        let groups = allKeyPaths.map { kp -> [LanguagePlatformKeyPath] in
            let v = lpInfo[keyPath: kp]
            let group = availableKeyPaths.filter {
                lpInfo[keyPath: $0].platforms == v.platforms
                    && lpInfo[keyPath: $0].swiftVersions == v.swiftVersions }
            availableKeyPaths.removeAll(where: { group.contains($0) })
            return group
        }
        .filter { !$0.isEmpty }
        return groups
    }

    func lpInfoSection(for keypaths: [LanguagePlatformKeyPath]) -> [Node<HTML.BodyContext>] {
        guard let leadingKeyPath = keypaths.first else { return [] }
        let cssClasses: [LanguagePlatformKeyPath: String] = [\.stable: "stable",
                                                             \.beta: "beta",
                                                             \.latest: "branch"]
        let nodes = keypaths.map { kp -> Node<HTML.BodyContext> in
            let info = languagePlatforms[keyPath: kp]
            let cssClass = cssClasses[kp]!
            return .a(
                .href(info.link.url),
                .span(
                    .class(cssClass),
                    .i(.class("icon \(cssClass)")),
                    .text(info.link.name)
                )
            )
        }

        // swift versions and platforms are the same all versions because we grouped them,
        // so we use the leading keypath to obtain it
        let versionInfo = languagePlatforms[keyPath: leadingKeyPath]

        return [
            .p(
                .group(Self.listPhrase(opening: .text("Version".pluralized(for: keypaths.count) + " "),
                                       nodes: nodes)),
                " \("supports".pluralized(for: keypaths.count, plural: "support")):"
            ),
            .ul(
                .li(
                    .group(versionsClause(versionInfo.swiftVersions))
                ),
                .li(
                    .group(platformsClause(versionInfo.platforms))
                )
            )
        ]
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
