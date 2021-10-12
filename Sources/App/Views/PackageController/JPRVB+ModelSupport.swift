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

import Fluent
import Foundation
import Vapor


extension JPRVB {
    static func query(on database: Database, owner: String, repository: String) -> EventLoopFuture<JPRVB> {
        JPR.query(on: database)
            .with(\.$versions) {
                $0.with(\.$products)
                $0.with(\.$builds)
            }
            .filter(Repository.self, \.$owner, .custom("ilike"), owner)
            .filter(Repository.self, \.$name, .custom("ilike"), repository)
            .first()
            .unwrap(or: Abort(.notFound))
            .map(JPRVB.init(jpr:))
    }

    func authors() -> [Link]? {
        // TODO: fill in
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/175
        return nil
    }
    
    func history() -> PackageShow.Model.History? {
        let releases = versions.filter({ $0.reference?.isRelease ?? false })
        guard
            let repo = repository,
            let commitCount = repo.commitCount,
            let defaultBranch = repo.defaultBranch,
            let firstCommitDate = repo.firstCommitDate,
            let commitCountString = Self.numberFormatter.string(from: NSNumber(value: commitCount)),
            let releaseCountString = Self.numberFormatter.string(from: NSNumber(value: releases.count))
        else { return nil }
        let cl = Link(
            label: commitCountString + " commit".pluralized(for: commitCount),
            url: model.url.droppingGitExtension + "/commits/\(defaultBranch)")
        let rl = Link(
            label: releaseCountString + " release".pluralized(for: releases.count),
            url: model.url.droppingGitExtension + "/releases")
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
            Link(label: pluralizedCount($0, singular: "open issue"), url: model.url.droppingGitExtension + "/issues")
        }
        let openPRs = repo.openPullRequests.map {
            Link(label: pluralizedCount($0, singular: "open pull request"), url: model.url.droppingGitExtension + "/pulls")
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
        guard let version = versions.latest(for: .defaultBranch) else { return nil }
        return .init(
            libraries: version.products.filter(\.isLibrary).count,
            executables: version.products.filter(\.isExecutable).count
        )
    }

    static func makeDatedLink(packageUrl: String, version: Version,
                              keyPath: KeyPath<Version, Date?>) -> DatedLink? {
        guard
            let date = version[keyPath: keyPath],
            let link = makeLink(packageUrl: packageUrl, version: version)
        else { return nil }
        return .init(date: "\(date: date, relativeTo: Current.date())",
                     link: link)
    }
    
    static func makeLink(packageUrl: String, version: Version) -> Link? {
        // TODO: review this $reference - this should not be required,
        // reference is not a relation and does not need to be loaded
        guard
            let fault = version.$reference.value,
            let ref = fault
        else { return nil }
        let linkUrl: String
        switch ref {
            case .branch:
                linkUrl = packageUrl
            case .tag(_ , let v):
                linkUrl = packageUrl.droppingGitExtension + "/releases/tag/\(v)"
        }
        return .init(label: "\(ref)", url: linkUrl)
    }
    
    static func makeModelVersion(packageUrl: String, version: Version) -> PackageShow.Model.Version? {
        guard let link = makeLink(packageUrl: packageUrl, version: version) else { return nil }
        return PackageShow.Model.Version(link: link,
                                         swiftVersions: version.swiftVersions.map(\.description),
                                         platforms: version.supportedPlatforms)
    }
    
    static func languagePlatformInfo(packageUrl: String, versions: [Version]) -> PackageShow.Model.LanguagePlatformInfo {
        let versions = [Version.Kind.release, .preRelease, .defaultBranch]
            .map {
                versions.latest(for: $0)
                    .flatMap {
                        makeModelVersion(packageUrl: packageUrl, version: $0)
                    }
            }
        return .init(stable: versions[0],
                     beta: versions[1],
                     latest: versions[2])
    }
    
    static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.thousandSeparator = ","
        f.numberStyle = .decimal
        return f
    }()
    
}


// MARK: - Build info


extension JPRVB {

    typealias BuildInfo = PackageShow.Model.BuildInfo
    typealias NamedBuildResults = PackageShow.Model.NamedBuildResults
    typealias SwiftVersionResults = PackageShow.Model.SwiftVersionResults
    typealias PlatformResults = PackageShow.Model.PlatformResults

    func swiftVersionBuildInfo() -> BuildInfo<SwiftVersionResults>? {
        .init(
            stable: versions.latest(for: .release).flatMap(Self.buildResults),
            beta: versions.latest(for: .preRelease).flatMap(Self.buildResults),
            latest: versions.latest(for: .defaultBranch).flatMap(Self.buildResults))

    }

    func platformBuildInfo() -> BuildInfo<PlatformResults>? {
        .init(
            stable: versions.latest(for: .release).flatMap(Self.buildResults),
            beta: versions.latest(for: .preRelease).flatMap(Self.buildResults),
            latest: versions.latest(for: .defaultBranch).flatMap(Self.buildResults)
        )
    }

    static func buildResults(_ version: Version) -> NamedBuildResults<SwiftVersionResults>? {
        guard let builds = version.$builds.value,
              let referenceName = version.reference?.description else { return nil }
        // For each reported swift version pick major/minor version matches
        let v5_0 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_0) }
        let v5_1 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_1) }
        let v5_2 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_2) }
        let v5_3 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_3) }
        let v5_4 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_4) }
        // ... and report the status
        return
            .init(referenceName: referenceName,
                  results: .init(status5_0: v5_0.buildStatus,
                                 status5_1: v5_1.buildStatus,
                                 status5_2: v5_2.buildStatus,
                                 status5_3: v5_3.buildStatus,
                                 status5_4: v5_4.buildStatus)
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
