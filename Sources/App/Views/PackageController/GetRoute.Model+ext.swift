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

import Foundation

import Dependencies
import DependencyResolution
import Plot
import SPIManifest
import Vapor


extension API.PackageController.GetRoute.Model {
    var gitHubOwnerUrl: String {
        "https://github.com/\(repositoryOwner)"
    }

    var gitHubRepositoryUrl: String {
        "https://github.com/\(repositoryOwner)/\(repositoryName)"
    }
}


extension API.PackageController.GetRoute.Model {
    static func makeModelVersion(packageUrl: String, version: App.Version) -> Version? {
        guard let link = makeLink(packageUrl: packageUrl, version: version) else { return nil }
        return Self.Version(link: link,
                            swiftVersions: version.swiftVersions.map { $0.description(droppingZeroes: .all) },
                            platforms: version.supportedPlatforms)
    }

    static func languagePlatformInfo(packageUrl: String,
                                     defaultBranchVersion: DefaultVersion?,
                                     releaseVersion: ReleaseVersion?,
                                     preReleaseVersion: PreReleaseVersion?) -> LanguagePlatformInfo {
        let versions = [releaseVersion?.model, preReleaseVersion?.model, defaultBranchVersion?.model]
            .map { version -> Version? in
                version.flatMap { makeModelVersion(packageUrl: packageUrl, version: $0) }
            }
        return .init(stable: versions[0],
                     beta: versions[1],
                     latest: versions[2])
    }
}


extension API.PackageController.GetRoute.Model {
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
                        .class("more-info"),
                        .href(SiteURL.faq.relativeURL(anchor: "licenses")),
                        "Why might the \(license.shortName) be problematic?"
                    )
                case .other:
                    return .a(
                        .class("more-info"),
                        .href(SiteURL.faq.relativeURL(anchor: "licenses")),
                        "Why is this package's license unknown?"
                    )
                case .none:
                    return .a(
                        .class("more-info"),
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
        guard let stars = stars else { return .empty }
        return .li(
            .class("stars"),
            .text("\(pluralizedCount: stars, singular: "star")")
        )
    }

    func authorsListItem() -> Node<HTML.ListContext> {
        guard let authors else { return .empty }

        switch authors {
            case .fromSPIManifest(var spiymlAuthors) :
                if spiymlAuthors.count > 200 {
                    spiymlAuthors = String(spiymlAuthors.prefix(200)) + "&hellip;"
                }

                return .li(
                    .class("authors"),
                    .text(spiymlAuthors)
                )

            case .fromGitRepository(let repositoryAuthors) :
                guard repositoryAuthors.hasAuthors else { return .empty }
                var nodes = repositoryAuthors.authors.map { author -> Node<HTML.BodyContext> in
                    return .text(author.name)
                }

                if repositoryAuthors.numberOfContributors > 0 {
                    let formattedNumberOfContributors = {
                        if let numberOfContributors = NumberFormatter.spiDefault.string(from: repositoryAuthors.numberOfContributors) {
                            return numberOfContributors
                        } else {
                            return "\(repositoryAuthors.numberOfContributors)"
                        }
                    }()
                    nodes.append(.text("\(formattedNumberOfContributors) other contributor"
                        .pluralized(for: repositoryAuthors.numberOfContributors)))
                }

                return .li(
                    .class("authors"),
                    .group(listPhrase(opening: "Written by ", nodes: nodes, closing: "."))
                )
        }
    }

    func archivedListItem() -> Node<HTML.ListContext> {
        if isArchived {
            return .li(
                .class("archived"),
                .strong("No longer in active development."),
                " The package author has archived this project and the repository is read-only."
            )
        } else {
            return .empty
        }
    }

    func forkedListItem() -> Node<HTML.ListContext> {
        if let forkedFromInfo {
            let item: Node<HTML.BodyContext> = {
                switch forkedFromInfo {
                case .fromGitHub(let url):
                    var text = url.replacingOccurrences(of: "https://github.com/", with: "")
                    text = text.removingSuffix(".git")
                    let repoURLNode: Node<HTML.BodyContext> = .a(
                        .href(url),
                        .text(text)
                    )
                    return  .group(
                        .text("Forked from "),
                        repoURLNode,
                        .text(".")
                    )
                case .fromSPI(_, let ownerName, _, let originalPackageName):
                    let repoURLNode: Node<HTML.BodyContext> = .a(
                        .href(forkedFromInfo.url),
                        .text("\(originalPackageName)")
                    )
                    let ownerNode: Node<HTML.BodyContext> = .a(
                        .href(forkedFromInfo.ownerURL ?? ""),
                        .text("\(ownerName)")
                    )
                    return  .group(
                        .text("Forked from "),
                        repoURLNode,
                        .text(" by "),
                        ownerNode,
                        .text(".")
                    )
                }
            }()

            return .li(
                .class("forked"),
                item
            )
        } else {
            return .empty
        }
    }

    func binaryTargetsItem() -> Node<HTML.ListContext> {
        guard hasBinaryTargets else { return .empty }

        func linkNode(for name: String, url: String) -> Node<HTML.BodyContext> {
            return .a(
                .href(url),
                .title(name),
                .text(name)
            )
        }

        return .li(
            .class("has-binary-targets"),
            .strong("This package includes binary-only targets "),
            .text("where source code may not be available. There may be more info available in the "),
            linkNode(for: "README", url: "#readme"),
            .unwrap(licenseUrl) { url in
                    .group([
                        " or ",
                        linkNode(for: "LICENSE", url: url)
                    ])
            },
            "."
        )
    }

    func historyListItem() -> Node<HTML.ListContext> {
        guard let history = history else { return .empty }

        let commitsLinkNode: Node<HTML.BodyContext> = .a(
            .href(history.commitCountURL),
            .text(history.commitCount.labeled("commit"))
        )

        let releasesLinkNode: Node<HTML.BodyContext> = .a(
            .href(history.releaseCountURL),
            .text(history.releaseCount.labeled("release"))
        )

        var releasesSentenceFragments: [Node<HTML.BodyContext>] = []
        if isArchived {
            releasesSentenceFragments.append(contentsOf: [
                "Before being archived, it had ",
                commitsLinkNode, " and ", releasesLinkNode, "."
            ])
        } else {
            @Dependency(\.date.now) var now
            releasesSentenceFragments.append(contentsOf: [
                "In development for \(inWords: now.timeIntervalSince(history.createdAt)), with ",
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
            activity.lastIssueClosedAt.map { .text("last issue was closed \($0.relative)") },
            activity.lastPullRequestClosedAt.map { .text("last pull request was merged/closed \($0.relative)") }
        ]
        .compactMap { $0 }

        return .li(
            .class("activity"),
            .group(listPhrase(opening: .text("There is ".pluralized(for: activity.openIssuesCount, plural: "There are ")), nodes: openItems, closing: ". ") + listPhrase(opening: "The ", nodes: lastClosed, conjunction: " and the ", closing: "."))
        )
    }

    func dependenciesListItem() -> Node<HTML.ListContext> {
        guard let dependenciesPhrase = dependenciesPhrase()
        else { return .empty }

        return .li(
            .class("dependencies"),
            .div(
                .text(dependenciesPhrase)
            ),
            .small(
                .text("Including all transitive and test dependencies.")
            )
        )
    }

    func dependenciesPhrase() -> String? {
        guard let dependencies = dependencies
        else { return nil }

        guard dependencies.count > 0
        else { return "This package has no package dependencies." }

        return "This package depends on \(pluralizedCount: dependencies.count, singular: "other package")."
    }

    func productTypeListItem(_ type: Product.ProductType) -> Node<HTML.ListContext> {
        guard let products = products
        else { return .empty }

        return .li(
            .class(type.cssClass),
            .text(products.filter({ $0.type == type }).count
                .labeled(type.singularForm, plural: type.pluralForm, capitalized: true))
        )
    }

    func targetTypeListItem(_ type: Target.TargetType) -> Node<HTML.ListContext> {
        guard let targets = targets
        else { return .empty }

        return .li(
            .class(type.cssClass),
            .text(targets.filter({ $0.type == type }).count
                .labeled(type.singularForm, plural: type.pluralForm, capitalized: true))
        )
    }

    func dataRaceSafeListItem() -> Node<HTML.ListContext> {
        guard let swift6Readiness else { return .empty }

        return .li(
            .class("data-race-safety"),
            .span(
                .text(swift6Readiness.text)
            ),
            .title(swift6Readiness.title),
            .a(
                .class("more-info"),
                .href(SiteURL.docs(.builds).relativeURL(anchor: "data-race-safety")),
                .text("What is data race safety and how is it tested?")
            )
        )
    }

    func keywordsListItem() -> Node<HTML.ListContext> {
        if let keywords = keywords {
            return .li(
                .class("keywords"),
                .spiOverflowingList(overflowMessage: "Show all \(keywords.count) tags…",
                                    overflowHeight: 52,
                    .class("keywords"),
                    .forEach(keywords, { keyword in
                        .li(
                            .a(
                                .href(SiteURL.keywords(.value(keyword)).relativeURL()),
                                .text("\(keyword)"),
                                .span(
                                    .class("count-tag"),
                                    .text("\(kiloPostfixedQuantity: weightedKeywords.weight(for: keyword))")
                                )
                            )
                        )
                    })
                )
            )
        } else {
            return .empty
        }
    }

    func customCollectionsListItem() -> Node<HTML.ListContext> {
        guard customCollections.isEmpty == false
        else { return .empty }

        let closing = if customCollections.count > 1 { " collections." } else { " collection." }

        return .li(
            .class("custom-collections"),
            .group(listPhrase(opening: .text("Member of the "),
                              nodes: customCollections.map({ collection in
                                      .a(
                                        .href(SiteURL.collections(.value(collection.key)).relativeURL()),
                                        .unwrap(collection.badge, { badge in
                                                .span(
                                                    .class("badge"),
                                                    .text(badge)
                                                )
                                        }),
                                        .text(collection.name)
                                      )
                              }),
                              closing: .text(closing))
            )
        )
    }

    func latestReleaseMetadata() -> Node<HTML.ListContext> {
        guard let dateLink = releases.stable else { return .empty }
        return releaseMetadata(dateLink, title: "Latest Release", cssClass: "stable")
    }

    func betaReleaseMetadata() -> Node<HTML.ListContext> {
        guard let dateLink = releases.beta else { return .empty }
        return releaseMetadata(dateLink, title: "Latest Beta Release", cssClass: "beta")
    }

    func defaultBranchMetadata() -> Node<HTML.ListContext> {
        guard let dateLink = releases.latest else { return .empty }
        return releaseMetadata(dateLink, title: "Default Branch", datePrefix: "Modified", cssClass: "branch")
    }

    func releaseMetadata(_ dateLink: DateLink, title: String, datePrefix: String = "Released", cssClass: String) -> Node<HTML.ListContext> {
        .li(
            .class(cssClass),
            .a(
                .href(dateLink.link.url),
                .span(
                    .class(cssClass),
                    .text(dateLink.link.label)
                )
            ),
            .strong(.text(title)),
            .small(.text([datePrefix, dateLink.date.relative].joined(separator: " ")))
        )
    }

    func xcodeprojDependencyForm(packageUrl: String) -> Node<HTML.BodyContext> {
        .copyableInputForm(buttonName: "Copy",
                           eventName: "Copy Xcodeproj Package URL Button",
                           valueToCopy: packageUrl)
    }

    func spmDependencyPackageForm(link: Link, cssClass: String) -> Node<HTML.BodyContext> {
        .div(
            .class("version"),
            .p(
                .span(
                    .class(cssClass),
                    .text(link.label)
                )
            ),
            .copyableInputForm(buttonName: "Copy",
                               eventName: "Copy SPM Manifest Code Snippet Button",
                               valueToCopy: link.url)
        )
    }

    func spmDependencyProductForm(package: String, products: [Product]) -> Node<HTML.BodyContext> {
        .div(
            .data(named: "controller", value: "use-this-package-panel"),
            .p(
                .label(
                    .for("products"),
                    "Select a product:"
                ),
                .select(
                    .data(named: "use-this-package-panel-target", value: "select"),
                    .data(named: "action", value: "input->use-this-package-panel#updateProductSnippet"),
                    .attribute(named: "name", value: "products"),
                    .id("products"),
                    // Filter out products of type `executable` until we add support for them.
                    .forEach(products.filter({ $0.type != .executable }), { product in
                            .option(
                                .data(named: "package", value: package),
                                .data(named: "product", value: product.name),
                                .data(named: "type", value: product.type.rawValue),
                                .value(product.name),
                                .label(product.name)
                            )
                    })
                )
            ),
            .copyableInputForm(buttonName: "Copy",
                               eventName: "Copy SPM Manifest Product Code Snippet Button",
                               inputNode: .data(named: "use-this-package-panel-target", value: "snippet"))
        )
    }

    func packageDependencyCodeSnippet(for release: App.Version.Kind) -> Link? {
        Self.packageDependencyCodeSnippet(for: release,
                                          releaseReferences: releaseReferences,
                                          packageURL: url)
    }

    static func packageDependencyCodeSnippet(for release: App.Version.Kind,
                                             releaseReferences: [App.Version.Kind: App.Reference],
                                             packageURL: String) -> Link? {
        guard let ref = releaseReferences[release] else { return nil }
        switch ref {
            case let .branch(branch):
                return Link(label: "\(ref)",
                            url: ".package(url: &quot;\(packageURL)&quot;, branch: &quot;\(branch)&quot;)")

            case let .tag(version, _):
                return Link(label: "\(ref)",
                            url: ".package(url: &quot;\(packageURL)&quot;, from: &quot;\(version)&quot;)")
        }
    }

    static func groupBuildInfo<T>(_ buildInfo: BuildInfo<T>) -> [PackageShow.BuildStatusRow<T>] {
        let allKeyPaths: [KeyPath<BuildInfo<T>, NamedBuildResults<T>?>] = [\.stable, \.beta, \.latest]
        var availableKeyPaths = allKeyPaths
        let groups = allKeyPaths.map { kp -> [KeyPath<BuildInfo<T>, NamedBuildResults<T>?>] in
            guard let r = buildInfo[keyPath: kp] else { return [] }
            let group = availableKeyPaths.filter { buildInfo[keyPath: $0]?.results == r.results }
            availableKeyPaths.removeAll(where: { group.contains($0) })
            return group
        }
        let rows = groups.compactMap { keyPaths -> PackageShow.BuildStatusRow<T>? in
            guard let first = keyPaths.first,
                  let results = buildInfo[keyPath: first]?.results else { return nil }
            let references = keyPaths.compactMap { kp -> PackageShow.Reference? in
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

    var hasBuildInfo: Bool { swiftVersionBuildInfo != nil || platformBuildInfo != nil }

    func compatibilityInformation() -> Node<HTML.BodyContext> {
        .div(
            .class("matrices"),
            swiftVersionCompatibilityList(),
            platformCompatibilityList()
        )
    }

    func swiftVersionCompatibilityList() -> Node<HTML.BodyContext> {
        guard let buildInfo = swiftVersionBuildInfo else { return .empty }
        let rows = Self.groupBuildInfo(buildInfo)
        return .a(
            .href(SiteURL.package(.value(repositoryOwner), .value(repositoryName), .builds).relativeURL()),
            .ul(
                .class("matrix compatibility"),
                .forEach(rows) { compatibilityListItem($0.labelParagraphNode, cells: $0.results.all) }
            )
        )
    }

    func platformCompatibilityList() -> Node<HTML.BodyContext> {
        guard let buildInfo = platformBuildInfo else { return .empty }
        let rows = Self.groupBuildInfo(buildInfo)
        return                         .a(
            .href(SiteURL.package(.value(repositoryOwner), .value(repositoryName), .builds).relativeURL()),
            .ul(
                .class("matrix compatibility"),
                .forEach(rows) { compatibilityListItem($0.labelParagraphNode, cells: $0.results.all) }
            )
        )
    }

    func compatibilityListItem<T: BuildResultPresentable>(
        _ labelParagraphNode: Node<HTML.BodyContext>,
        cells: [CompatibilityMatrix.BuildResult<T>]
    ) -> Node<HTML.ListContext> {
        return .li(
            .class("row"),
            .div(
                .class("row-labels"),
                labelParagraphNode
            ),
            // Matrix CSS should include *both* the column labels, and the column values status boxes in *every* row.
            .div(
                .class("column-labels"),
                .forEach(cells) { $0.headerNode }
            ),
            .div(
                .class("results"),
                .forEach(cells) { $0.cellNode }
            )
        )
    }

    func noCompatibilityInformationExplainer() -> Node<HTML.BodyContext> {
        @Dependency(\.environment) var environment

        return .if(environment.processingBuildBacklog(),
            .group(
                .p(
                    .text("This package currently has no compatibility information. "),
                    .strong("We are currently processing a large build job backlog and it may take much longer than usual for compatibility information to appear.")
                ),
                .p(
                    .text("You can see what builds the system is currently processing by checking the "),
                    .a(
                        .href(SiteURL.buildMonitor.relativeURL()),
                        .text("build system monitoring page")
                    ),
                    .text(".")
                )
            ),
            else: .group(
                .p("This package currently has no compatibility information. The build jobs that determine compatibility have been queued and compatibility information will appear when they complete."),
                .p(
                    .text("If this message persists for more than an hour, please "),
                    .a(
                        .href(ExternalURL.raiseNewIssue),
                        .text("raise an issue")
                    ),
                    .text(".")
                )
            ))
    }
}


// MARK: - Nested type extensions

extension API.PackageController.GetRoute.Model.Activity {
    var openIssues: Link? {
        guard let url = openIssuesURL else { return nil }
        return .init(label: openIssuesCount.labeled("open issue"), url: url)
    }

    var openPullRequests: Link? {
        guard let url = openPullRequestsURL else { return nil }
        return .init(label: openPullRequestsCount.labeled("open pull request"),
                     url: url)
    }
}


// MARK: - General helpers

private extension License.Kind {
    var cssClass: String {
        switch self {
            case .none: return "no-license"
            case .incompatibleWithAppStore, .other: return "incompatible_license"
            case .compatibleWithAppStore: return "compatible_license"
        }
    }
}


private extension CompatibilityMatrix.BuildResult where T: BuildResultPresentable {
    var headerNode: Node<HTML.BodyContext> {
        .div(
            .text(parameter.displayName),
            .unwrap(parameter.note) { .small(.text("(\($0))")) }
        )
    }

    var cellNode: Node<HTML.BodyContext> {
        .div(
            .class("\(status.cssClass)"),
            .title(title)
        )
    }

    var title: String {
        switch status {
            case .compatible:
                return "Built successfully with \(parameter.longDisplayName)"
            case .incompatible:
                return "Build failed with \(parameter.longDisplayName)"
            case .unknown:
                return "No build information available for \(parameter.longDisplayName)"
        }
    }
}

private extension CompatibilityMatrix.Compatibility {
    var cssClass: String {
        self.rawValue
    }
}

private extension API.PackageController.GetRoute.Model.Product.ProductType {
    var cssClass: String {
        switch self {
            case .executable: return "executables"
            case .library: return "libraries"
            case .plugin: return "plugins"
        }
    }

    var singularForm: String {
        switch self {
            case .executable: return "executable"
            case .library: return "library"
            case .plugin: return "plugin"
        }
    }

    var pluralForm: String {
        switch self {
            case .executable: return "executables"
            case .library: return "libraries"
            case .plugin: return "plugins"
        }
    }
}

private extension API.PackageController.GetRoute.Model.Target.TargetType {
    var cssClass: String {
        switch self {
            case .macro: return "macros"
            case .test: return "tests"
        }
    }

    var singularForm: String {
        switch self {
            case .macro: return "macro"
            case .test: return "test"
        }
    }

    var pluralForm: String {
        switch self {
            case .macro: return "macros"
            case .test: return "tests"
        }
    }
}


extension API.PackageController.GetRoute.Model.Swift6Readiness {
    var text: String {
        switch dataRaceSafety {
            case .safe:
                return "Zero data race safety errors"
            case .unsafe:
                return "Has data race safety errors"
            case .unknown:
                return "No data race safety information available"
        }
    }

    var title: String {
        guard !errorCounts.isEmpty else { return "No data available" }
        var lines = ["Error counts:"]
        for platform in errorCounts.keys.sorted() {
            lines.append("\(platform.displayName): \(errorCounts[platform].map { "\($0)" } ?? "no data")")
        }
        return lines.joined(separator: "\n")
    }
}


extension API.PackageController.GetRoute.Model.ForkedFromInfo {
    var url: String {
        switch self {
        case .fromSPI(let originalOwner, _, let originalRepo, _):
            return SiteURL.package(.value(originalOwner), .value(originalRepo), nil).relativeURL()
        case .fromGitHub(let url):
            return url
        }
    }

    var ownerURL: String? {
        switch self {
        case .fromSPI(let owner, _, _, _):
            return SiteURL.author(.value(owner)).relativeURL()
        case .fromGitHub:
            return nil
        }
    }
}
