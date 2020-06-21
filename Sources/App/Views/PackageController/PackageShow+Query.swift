import Fluent
import Foundation
import Vapor


extension PackageShow.Model {

    static func query(database: Database, owner: String, repository: String) -> EventLoopFuture<Self> {
        let res = Package.query(on: database)
            .with(\.$repositories)
            .with(\.$versions) { $0.with(\.$products) }
            .join(Repository.self, on: \Repository.$package.$id == \Package.$id)
            // TODO: make less verbose once fixed in Fluent:
            // https://github.com/vapor/fluent-kit/issues/310
            .filter(
                DatabaseQuery.Field.path(Repository.path(for: \.$owner), schema: Repository.schema),
                DatabaseQuery.Filter.Method.custom("ilike"),
                DatabaseQuery.Value.bind(owner)
            )
            .filter(
                DatabaseQuery.Field.path(Repository.path(for: \.$name), schema: Repository.schema),
                DatabaseQuery.Filter.Method.custom("ilike"),
                DatabaseQuery.Value.bind(repository)
            )
            .first()
        
        return res.unwrap(or: Abort(.notFound))
            .map { p -> Self? in
                // we consider certain attributes as essential and return nil (raising .notFound)
                guard let title = p.name() else { return nil }
                return Self.init(
                    activity: p.activity(),
                    authors: p.authors(),
                    history: p.history(),
                    languagePlatforms: p.languagePlatformInfo(),
                    license: p.repository?.license ?? .none,
                    products: p.productCounts(),
                    releases: p.releaseInfo(),
                    stars: p.repository?.stars,
                    // FIXME: we should probably also display an explainer
                    // when summary is nil
                    summary: p.repository?.summary ?? "–",
                    title: title,
                    url: p.url
                )
            }
            .unwrap(or: Abort(.notFound))
    }

}


extension Package {
    func defaultVersion() -> Version? {
        guard
            let versions = $versions.value,
            let repositories = $repositories.value,
            let repo = repositories.first,
            let defaultBranch = repo.defaultBranch
            else { return nil }
        return versions.first(where: { v in
            guard let ref = v.reference else { return false }
            switch ref {
                case .branch(let b) where b == defaultBranch:
                    return true
                default:
                    return false
            }
        })
    }

    func name() -> String? { defaultVersion()?.packageName }

    func authors() -> [Link]? {
        // TODO: fill in
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/175
        return nil
    }

    func history() -> PackageShow.Model.History? {
        guard
            let repo = repository,
            let commitCount = repo.commitCount,
            let defaultBranch = repo.defaultBranch,
            let releases = $versions.value?.filter({ $0.reference?.isRelease ?? false }),
            let firstCommitDate = repo.firstCommitDate,
            let commitCountString = Self.numberFormatter.string(from: NSNumber(value: commitCount)),
            let releaseCountString = Self.numberFormatter.string(from: NSNumber(value: releases.count))
            else { return nil }
        let cl = Link(
            label: commitCountString + " commit".pluralized(for: commitCount),
            url: url.droppingGitExtension + "/commits/\(defaultBranch)")
        let rl = Link(
            label: releaseCountString + " release".pluralized(for: releases.count),
            url: url.droppingGitExtension + "/releases")
        let timeSinceFirstCommit = Current.date().timeIntervalSince(firstCommitDate)
        return .init(since: "\(inWords: timeSinceFirstCommit)",
                     commitCount: cl,
                     releaseCount: rl,
                     releaseCadence: releases.isEmpty ? nil : "\(inWords: timeSinceFirstCommit / Double(releases.count))")
    }

    func activity() -> PackageShow.Model.Activity? {
        guard
            let repo = repository,
            repo.openIssues != nil || repo.openPullRequests != nil || repo.lastPullRequestClosedAt != nil
            else { return nil }
        let openIssues = repo.openIssues.map {
            Link(label: pluralizedCount($0, singular: "open issue"), url: url.droppingGitExtension + "/issues")
        }
        let openPRs = repo.openPullRequests.map {
            Link(label: pluralizedCount($0, singular: "open pull request"), url: url.droppingGitExtension + "/pulls")
        }
        let lastIssueClosed = repo.lastIssueClosedAt.map { "\(date: $0, relativeTo: Current.date())" }
        let lastPRClosed = repo.lastPullRequestClosedAt.map { "\(date: $0, relativeTo: Current.date())" }
        return .init(openIssuesCount: repo.openIssues ?? 0,
                     openIssues: openIssues,
                     openPullRequests: openPRs,
                     lastIssueClosedAt: lastIssueClosed,
                     lastPullRequestClosedAt: lastPRClosed)
    }

    func productCounts() -> PackageShow.Model.ProductCounts? {
        guard let version = defaultVersion() else { return nil }
        return .init(
            libraries: version.products.filter(\.isLibrary).count,
            executables: version.products.filter(\.isExecutable).count
        )
    }

    func releases() -> (stable: Version?, beta: Version?, latest: Version?) {
        guard let versions = $versions.value else { return (nil, nil, nil) }
        let releases = versions
            .filter { $0.reference?.semVer != nil }
            .sorted { $0.reference!.semVer! < $1.reference!.semVer! }
        let stable = releases.reversed().first { $0.reference?.semVer?.isStable ?? false }
        let beta = releases.reversed().first {
            // pick first version that is a prerelease *and* no older (in terms of SemVer)
            // than stable
            ($0.reference?.semVer?.isPreRelease ?? false)
                && ($0.reference?.semVer ?? SemVer(0, 0, 0)
                    >= stable?.reference?.semVer ?? SemVer(0, 0, 0))
        }
        let latest = defaultVersion()
        return (stable, beta, latest)
    }

    func releaseInfo() -> PackageShow.Model.ReleaseInfo {
        let (stable, beta, latest) = releases()
        return .init(stable: stable.flatMap { makeDatedLink($0, \.commitDate) },
                     beta: beta.flatMap { makeDatedLink($0, \.commitDate) },
                     latest: latest.flatMap { makeDatedLink($0, \.commitDate) })
    }

    func makeDatedLink(_ version: Version,
                       _ keyPath: KeyPath<Version, Date?>) -> DatedLink? {
        guard
            let date = version[keyPath: keyPath],
            let link = makeLink(version)
            else { return nil }
        return .init(date: "\(date: date, relativeTo: Current.date())",
                     link: link)
    }

    func makeLink(_ version: Version) -> Link? {
        guard
            // FIXME: test eager loading resolution
            let fault = version.$reference.value,
            let ref = fault
            else { return nil }
        let linkUrl: String
        switch ref {
            case .branch:
                linkUrl = url
            case .tag(_ , let v):
                linkUrl = url.droppingGitExtension + "/releases/tag/\(v)"
        }
        return .init(label: "\(ref)", url: linkUrl)
    }

    func makeModelVersion(_ version: Version) -> PackageShow.Model.Version? {
        guard let link = makeLink(version) else { return nil }
        return PackageShow.Model.Version(link: link,
                                         swiftVersions: version.swiftVersions.map(\.description),
                                         platforms: version.supportedPlatforms)
    }

    func languagePlatformInfo() -> PackageShow.Model.LanguagePlatformInfo {
        let (stable, beta, latest) = releases()
        return .init(stable: stable.flatMap(makeModelVersion),
                     beta: beta.flatMap(makeModelVersion),
                     latest: latest.flatMap(makeModelVersion))
    }

    static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.thousandSeparator = ","
        f.numberStyle = .decimal
        return f
    }()
}
