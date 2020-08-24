import Fluent
import Foundation
import Vapor


extension Package {
    
    static func query(on database: Database, owner: String, repository: String) -> EventLoopFuture<Package> {
        Package.query(on: database)
            .with(\.$repositories)
            .with(\.$versions) {
                $0.with(\.$products)
                $0.with(\.$builds)
            }
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
            .unwrap(or: Abort(.notFound))
    }

    func latestVersion(for kind: Version.Kind) -> Version? {
        guard let versions = $versions.value else { return nil }
        return versions.first { $0.latest == kind }
    }

    func name() -> String? { latestVersion(for: .defaultBranch)?.packageName }
    
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
        return .init(since: "\(inWords: Current.date().timeIntervalSince(firstCommitDate))",
                     commitCount: cl,
                     releaseCount: rl)
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
        guard let version = latestVersion(for: .defaultBranch) else { return nil }
        return .init(
            libraries: version.products.filter(\.isLibrary).count,
            executables: version.products.filter(\.isExecutable).count
        )
    }

    func releaseInfo() -> PackageShow.Model.ReleaseInfo {
        .init(
            stable: latestVersion(for: .release).flatMap { makeDatedLink($0, \.commitDate) },
            beta: latestVersion(for: .preRelease).flatMap { makeDatedLink($0, \.commitDate) },
            latest: latestVersion(for: .defaultBranch).flatMap { makeDatedLink($0, \.commitDate) }
        )
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
        .init(
            stable: latestVersion(for: .release).flatMap(makeModelVersion),
            beta: latestVersion(for: .preRelease).flatMap(makeModelVersion),
            latest: latestVersion(for: .defaultBranch).flatMap(makeModelVersion)
        )
    }
    
    static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.thousandSeparator = ","
        f.numberStyle = .decimal
        return f
    }()
}


// MARK: - Build info


extension Package {

    typealias BuildInfo = PackageShow.Model.BuildInfo
    typealias NamedBuildResults = PackageShow.Model.NamedBuildResults
    typealias SwiftVersionResults = PackageShow.Model.SwiftVersionResults
    typealias PlatformResults = PackageShow.Model.PlatformResults

    func swiftVersionBuildInfo() -> BuildInfo<SwiftVersionResults>? {
        .init(
            stable: latestVersion(for: .release).flatMap(Package.buildResults),
            beta: latestVersion(for: .preRelease).flatMap(Package.buildResults),
            latest: latestVersion(for: .defaultBranch).flatMap(Package.buildResults))

    }

    func platformBuildInfo() -> BuildInfo<PlatformResults>? {
        .init(
            stable: latestVersion(for: .release).flatMap(Package.buildResults),
            beta: latestVersion(for: .preRelease).flatMap(Package.buildResults),
            latest: latestVersion(for: .defaultBranch).flatMap(Package.buildResults)
        )
    }

    static func buildResults(_ version: Version) -> NamedBuildResults<SwiftVersionResults>? {
        guard let builds = version.$builds.value,
              let referenceName = version.reference?.description else { return nil }
        // For each reported swift version pick major/minor version matches
        let v4_2 = builds.filter { $0.swiftVersion.isCompatible(with: .v4_2) }
        let v5_0 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_0) }
        let v5_1 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_1) }
        let v5_2 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_2) }
        let v5_3 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_3) }
        // ... and report the status
        return
            .init(referenceName: referenceName,
                  results: .init(status4_2: v4_2.buildStatus,
                                 status5_0: v5_0.buildStatus,
                                 status5_1: v5_1.buildStatus,
                                 status5_2: v5_2.buildStatus,
                                 status5_3: v5_3.buildStatus)
            )
    }

    static func buildResults(_ version: Version) -> NamedBuildResults<PlatformResults>? {
        guard let builds = version.$builds.value,
              let referenceName = version.reference?.description else { return nil }
        // For each reported platform pick appropriate build matches
        let ios = builds.filter { $0.platform.isCompatible(with: .ios) }
        let linux = builds.filter { $0.platform.isCompatible(with: .linux) }
        let macos = builds.filter { $0.platform.isCompatible(with: .macos) }
        let macosArm = builds.filter { $0.platform.isCompatible(with: .macosArm) }
        let tvos = builds.filter { $0.platform.isCompatible(with: .tvos) }
        let watchos = builds.filter { $0.platform.isCompatible(with: .watchos) }
        // ... and report the status
        return
            .init(referenceName: referenceName,
                  results: .init(iosStatus: ios.buildStatus,
                                 linuxStatus: linux.buildStatus,
                                 macosStatus: macos.buildStatus,
                                 macosArmStatus: macosArm.buildStatus,
                                 tvosStatus: tvos.buildStatus,
                                 watchosStatus: watchos.buildStatus)
            )
    }

}


extension Array where Element == Build {
    var buildStatus: PackageShow.Model.BuildStatus {
        guard !isEmpty else { return .unknown }
        if anySucceeded {
            return .compatible
        } else {
            return anyPending ? .unknown : .incompatible
        }
    }
}


private extension Build.Platform {
    func isCompatible(with other: PackageShow.Model.PlatformCompatibility) -> Bool {
        switch self {
            case .ios:
                return other == .ios
            case .macosSpm, .macosXcodebuild:
                return other == .macos
            case .macosSpmArm, .macosXcodebuildArm:
                return other == .macosArm
            case .tvos:
                return other == .tvos
            case .watchos:
                return other == .watchos
            case .linux:
                return other == .linux
        }
    }
}
