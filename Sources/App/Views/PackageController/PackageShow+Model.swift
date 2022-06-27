// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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
import Plot
import Vapor
import DependencyResolution
import SPIManifest


extension PackageShow {
    
    struct Model: Equatable {
        var packageId: Package.Id
        var repositoryOwner: String
        var repositoryOwnerName: String
        var repositoryName: String
        var activity: Activity?
        var authors: [Link]?
        var keywords: [String]?
        var swiftVersionBuildInfo: BuildInfo<SwiftVersionResults>?
        var platformBuildInfo: BuildInfo<PlatformResults>?
        var history: History?
        var languagePlatforms: LanguagePlatformInfo
        var license: License
        var licenseUrl: String?
        var productCounts: ProductCounts?
        var releases: ReleaseInfo
        var dependencies: [ResolvedDependency]?
        var stars: Int?
        var summary: String?
        var title: String
        var url: String
        var score: Int?
        var isArchived: Bool
        var homepageUrl: String?
        var documentationMetadata: DocumentationMetadata?
        var dependencyCodeSnippets: [Release.Kind: Link]
        
        internal init(packageId: Package.Id,
                      repositoryOwner: String,
                      repositoryOwnerName: String,
                      repositoryName: String,
                      activity: Activity? = nil,
                      authors: [Link]? = nil,
                      keywords: [String]? = nil,
                      swiftVersionBuildInfo: BuildInfo<SwiftVersionResults>? = nil,
                      platformBuildInfo: BuildInfo<PlatformResults>? = nil,
                      history: History? = nil,
                      languagePlatforms: LanguagePlatformInfo,
                      license: License,
                      licenseUrl: String? = nil,
                      productCounts: ProductCounts? = nil,
                      releases: ReleaseInfo,
                      dependencies: [ResolvedDependency]?,
                      stars: Int? = nil,
                      summary: String?,
                      title: String,
                      url: String,
                      score: Int? = nil,
                      isArchived: Bool,
                      homepageUrl: String? = nil,
                      documentationMetadata: DocumentationMetadata? = nil,
                      dependencyCodeSnippets: [Release.Kind: Link]) {
            self.packageId = packageId
            self.repositoryOwner = repositoryOwner
            self.repositoryOwnerName = repositoryOwnerName
            self.repositoryName = repositoryName
            self.activity = activity
            self.authors = authors
            self.keywords = keywords
            self.swiftVersionBuildInfo = swiftVersionBuildInfo
            self.platformBuildInfo = platformBuildInfo
            self.history = history
            self.languagePlatforms = languagePlatforms
            self.license = license
            self.licenseUrl = licenseUrl
            self.productCounts = productCounts
            self.releases = releases
            self.dependencies = dependencies
            self.stars = stars
            self.summary = summary
            self.title = title
            self.url = url
            self.score = score
            self.isArchived = isArchived
            self.homepageUrl = homepageUrl
            self.documentationMetadata = documentationMetadata
            self.dependencyCodeSnippets = dependencyCodeSnippets
        }
        
        init?(result: PackageController.PackageResult,
              history: History?,
              productCounts: ProductCounts,
              swiftVersionBuildInfo: BuildInfo<SwiftVersionResults>?,
              platformBuildInfo: BuildInfo<PlatformResults>?) {
            // we consider certain attributes as essential and return nil (raising .notFound)
            let repository = result.repository
            guard
                let repositoryOwner = repository.owner,
                let repositoryOwnerName = repository.ownerDisplayName,
                let repositoryName = repository.name,
                let packageId = result.package.id
            else { return nil }

            #warning("temporary hotfix until #1770 is properly addressed")
            let docTargetOverrides = [
                "https://github.com/apple/swift-docc.git".lowercased() : "DocC",
                "https://github.com/apple/swift-markdown.git".lowercased() : "Markdown",
                "https://github.com/parse-community/Parse-Swift.git".lowercased() : "ParseSwift",
            ]
            let defaulDocTarget = docTargetOverrides[result.package.url.lowercased()]
            ?? result.defaultBranchVersion.spiManifest?
                .allDocumentationTargets()?
                .first

            self.init(
                packageId: packageId,
                repositoryOwner: repositoryOwner,
                repositoryOwnerName: repositoryOwnerName,
                repositoryName: repositoryName,
                activity: result.activity(),
                authors: result.authors(),
                keywords: repository.keywords,
                swiftVersionBuildInfo: swiftVersionBuildInfo,
                platformBuildInfo: platformBuildInfo,
                history: history,
                languagePlatforms: Self.languagePlatformInfo(
                    packageUrl: result.package.url,
                    defaultBranchVersion: result.defaultBranchVersion,
                    releaseVersion: result.releaseVersion,
                    preReleaseVersion: result.preReleaseVersion),
                license: repository.license,
                licenseUrl: repository.licenseUrl,
                productCounts: productCounts,
                releases: PackageShow.releaseInfo(
                    packageUrl: result.package.url,
                    defaultBranchVersion: result.defaultBranchVersion,
                    releaseVersion: result.releaseVersion,
                    preReleaseVersion: result.preReleaseVersion),
                dependencies: result.defaultBranchVersion.resolvedDependencies,
                stars: repository.stars,
                summary: repository.summary,
                title: result.defaultBranchVersion.packageName ?? repositoryName,
                url: result.package.url,
                score: result.package.score,
                isArchived: repository.isArchived,
                homepageUrl: repository.homepageUrl,
                documentationMetadata: DocumentationMetadata(
                    reference: result.repository.defaultBranch,
                    defaultTarget: defaulDocTarget),
                dependencyCodeSnippets: Self.packageDependencyCodeSnippets(
                    packageURL: result.package.url,
                    defaultBranchReference: result.defaultBranchVersion.model.reference,
                    releaseReference: result.releaseVersion?.model.reference,
                    preReleaseReference: result.preReleaseVersion?.model.reference)
            )

        }
    }

    struct DocumentationMetadata: Equatable {
        let reference: String
        let defaultTarget: String

        init?(reference: String?, defaultTarget: String?) {
            guard
                let reference = reference,
                let defaultTarget = defaultTarget
            else { return nil }

            self.reference = reference
            self.defaultTarget = defaultTarget
        }
    }
    
}

extension PackageShow.Model {
    var gitHubOwnerUrl: String {
        "https://github.com/\(repositoryOwner)"
    }

    var gitHubRepositoryUrl: String {
        "https://github.com/\(repositoryOwner)/\(repositoryName)"
    }

    // Note: When this gets merged back with the refactored SiteURL, note that it's duplicated in `DocumentationPageProcessor`.
    func relativeDocumentationURL(reference: String, target: String) -> String {
        "/\(repositoryOwner)/\(repositoryName)/\(reference)/documentation/\(target.lowercased())"
    }
}

extension PackageShow.Model {
    static func makeModelVersion(packageUrl: String, version: App.Version) -> Version? {
        guard let link = makeLink(packageUrl: packageUrl, version: version) else { return nil }
        return PackageShow.Model.Version(link: link,
                                         swiftVersions: version.swiftVersions.map(\.description),
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
              let str = NumberFormatter.spiDefault.string(from: stars)
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
                "Before being archived, it had ",
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

    func dependenciesListItem() -> Node<HTML.ListContext> {
        guard let dependenciesPhrase = dependenciesPhrase()
        else { return .empty }

        return .li(
            .class("dependencies"),
            .text(dependenciesPhrase)
        )
    }

    func dependenciesPhrase() -> String? {
        guard let dependencies = dependencies
        else { return nil }

        guard dependencies.count > 0
        else { return "This package has no package dependencies." }

        let dependenciesCount = pluralizedCount(dependencies.count, singular: "other package")
        return "This package depends on \(dependenciesCount)."
    }

    func librariesListItem() -> Node<HTML.ListContext> {
        guard let productCounts = productCounts
        else { return .empty }

        return .li(
            .class("libraries"),
            .text(pluralizedCount(productCounts.libraries, singular: "library", plural: "libraries", capitalized: true))
        )
    }

    func executablesListItem() -> Node<HTML.ListContext> {
        guard let productCounts = productCounts
        else { return .empty }

        return .li(
            .class("executables"),
            .text(pluralizedCount(productCounts.executables, singular: "executable", capitalized: true))
        )
    }

    func pluginsListItem() -> Node<HTML.ListContext> {
        guard let productCounts = productCounts
        else { return .empty }

        return .li(
            .class("plugins"),
            .text(pluralizedCount(productCounts.plugins, singular: "plugin", capitalized: true))
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
                                .text(keyword)
                            )
                        )
                    })
                )
            )
        } else {
            return .empty
        }
    }

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

    func xcodeprojDependencyForm(packageUrl: String) -> Node<HTML.BodyContext> {
        .copyableInputForm(buttonName: "Copy Package URL",
                           eventName: "Copy Xcodeproj Package URL Button",
                           valueToCopy: packageUrl)
    }

    func spmDependencyForm(link: Link, cssClass: String) -> Node<HTML.BodyContext> {
        .group(
            .p(
                .span(
                    .class(cssClass),
                    .text(link.label)
                )
            ),
            .copyableInputForm(buttonName: "Copy Code Snippet",
                               eventName: "Copy SPM Manifest Code Snippet Button",
                               valueToCopy: link.url)
        )
    }

    static func packageDependencyCodeSnippet(ref: App.Reference, packageURL: String) -> String {
        switch ref {
            case let .branch(branch):
                return ".package(url: &quot;\(packageURL)&quot;, branch: &quot;\(branch)&quot;)"

            case let .tag(version, _):
                return ".package(url: &quot;\(packageURL)&quot;, from: &quot;\(version)&quot;)"
        }
    }

    static func packageDependencyCodeSnippets(packageURL: String,
                                              defaultBranchReference: App.Reference?,
                                              releaseReference: App.Reference?,
                                              preReleaseReference: App.Reference?) -> [Release.Kind: Link] {
        var snippets = [Release.Kind: Link]()
        if let ref = defaultBranchReference {
            snippets[.defaultBranch] = Link(label: "\(ref)",
                                            url: packageDependencyCodeSnippet(ref: ref,
                                                                              packageURL: packageURL))
        }
        if let ref = releaseReference {
            snippets[.release] = Link(label: "\(ref)",
                                      url: packageDependencyCodeSnippet(ref: ref,
                                                                        packageURL: packageURL))
        }
        if let ref = preReleaseReference {
            snippets[.preRelease] = Link(label: "\(ref)",
                                         url: packageDependencyCodeSnippet(ref: ref,
                                                                           packageURL: packageURL))
        }
        return snippets
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

    var hasBuildInfo: Bool { swiftVersionBuildInfo != nil || platformBuildInfo != nil }

    func swiftVersionCompatibilityList() -> Node<HTML.BodyContext> {
        guard let buildInfo = swiftVersionBuildInfo else { return .empty }
        let rows = Self.groupBuildInfo(buildInfo)
        return .a(
            .href(SiteURL.package(.value(repositoryOwner), .value(repositoryName), .builds).relativeURL()),
            .ul(
                .class("matrix compatibility"),
                .forEach(rows) { compatibilityListItem($0.labelParagraphNode, cells: $0.results.cells) }
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
                .forEach(rows) { compatibilityListItem($0.labelParagraphNode, cells: $0.results.cells) }
            )
        )
    }

    func compatibilityListItem<T>(_ labelParagraphNode: Node<HTML.BodyContext>,
                                  cells: [BuildResult<T>]) -> Node<HTML.ListContext> {
        return .li(
            .class("row"),
            .div(
                .class("row_labels"),
                labelParagraphNode
            ),
            // Matrix CSS should include *both* the column labels, and the column values status boxes in *every* row.
            .div(
                .class("column_labels"),
                .forEach(cells) { $0.headerNode }
            ),
            .div(
                .class("results"),
                .forEach(cells) { $0.cellNode }
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
            case .custom:
                return 4
            case .driverkit:
                return 6
            case .maccatalyst:
                return 5
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
