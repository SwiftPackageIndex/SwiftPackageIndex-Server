import Fluent
import Foundation
import Vapor


extension PackageShow.Model {
    static func query(database: Database, packageId: Package.Id) -> EventLoopFuture<Self> {
        Package.query(on: database)
            .with(\.$repositories)
            .with(\.$versions) { $0.with(\.$products) }
            .filter(\.$id == packageId)
            .first()
            .unwrap(or: Abort(.notFound))
            .map { p -> Self? in
                // we consider certain attributes as essential and return nil (raising .notFound)
                guard let title = p.name() else { return nil }
                return Self.init(title: title,
                                 url: p.url,
                                 license: p.repository?.license ?? .none,
                                 summary: p.repository?.summary ?? "–",
                                 authors: [],      // TODO: fill in
                                 history: p.history(),
                                 activity: nil,    // TODO: fill in
                                 products: p.productCounts(),
                                 releases: p.releaseInfo(),
                                 languagePlatforms: p.languagePlatformInfo())
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
        let beta = releases.reversed().first { $0.reference?.semVer?.isPrerelease ?? false }
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
                       _ keyPath: KeyPath<Version, Date?>) -> PackageShow.Model.DatedLink? {
        guard
            let date = version[keyPath: keyPath],
            let link = makeLink(version)
            else { return nil }
        return .init(date: "\(date: date, relativeTo: Current.date())",
                     link: link)
    }

    func makeLink(_ version: Version) -> PackageShow.Model.Link? {
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
                                         swiftVersions: version.swiftVersions,
                                         platforms: version.supportedPlatforms)
    }

    func languagePlatformInfo() -> PackageShow.Model.LanguagePlatformInfo {
        let (stable, beta, latest) = releases()
        return .init(stable: stable.flatMap(makeModelVersion),
                     beta: beta.flatMap(makeModelVersion),
                     latest: latest.flatMap(makeModelVersion))
    }

    func history() -> PackageShow.Model.History? {
        guard
            let repo = repository,
            let commitCount = repo.commitCount,
            let defaultBranch = repo.defaultBranch,
            let releases = $versions.value,
            let firstCommitDate = repo.firstCommitDate,
            let commitCountString = Self.numberFormatter.string(from: NSNumber(value: commitCount)),
            let releaseCountString = Self.numberFormatter.string(from: NSNumber(value: releases.count))
            else { return nil }
        let cl = PackageShow.Model.Link(
            label: commitCountString + " commit".pluralized(for: commitCount),
            url: url.droppingGitExtension + "/commits/\(defaultBranch)")
        let rl = PackageShow.Model.Link(
            label: releaseCountString + " release".pluralized(for: releases.count),
            url: url.droppingGitExtension + "/releases")
        return .init(since: "\(inWords: Current.date().timeIntervalSince(firstCommitDate))",
                     commitCount: cl,
                     releaseCount: rl)
    }

    static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.thousandSeparator = ","
        f.numberStyle = .decimal
        return f
    }()
}
