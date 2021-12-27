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
import SQLKit
import Vapor


extension PackageController {
    typealias PackageResult = Joined5<Package, Repository, DefaultVersion, ReleaseVersion, PreReleaseVersion>

    enum ShowRoute {

        /// Assembles individual queries and transforms them into model structs.
        /// - Parameters:
        ///   - database: `Database`
        ///   - owner: repository owner
        ///   - repository: repository name
        /// - Returns: model structs
        static func query(on database: Database, owner: String, repository: String) -> EventLoopFuture<(model: PackageShow.Model, schema: PackageShow.PackageSchema)> {
            PackageResult.query(on: database, owner: owner, repository: repository)
                .and(History.query(on: database, owner: owner, repository: repository))
                .and(ProductCount.query(on: database, owner: owner, repository: repository))
                .and(BuildInfo.query(on: database, owner: owner, repository: repository))
                .map {
                    // This monster will go away when we switch to async/await,
                    // leaving this in for now, it should be short-lived
                    ($0.0.0.0, $0.0.0.1, $0.0.1, $0.1)
                }
                .map { (packageResult, historyResult, productTypes, buildInfo) -> (model: PackageShow.Model, schema: PackageShow.PackageSchema)? in
                    guard
                        let model = PackageShow.Model(
                            result: packageResult,
                            history: historyResult?.history(),
                            productCounts: .init(
                                libraries: productTypes.filter(\.isLibrary).count,
                                executables: productTypes.filter(\.isExecutable).count),
                            swiftVersionBuildInfo: buildInfo.swiftVersion,
                            platformBuildInfo: buildInfo.platform
                        ),
                        let schema = PackageShow.PackageSchema(result: packageResult)
                    else {
                        return nil
                    }

                    return (model, schema)
                }
                .unwrap(or: Abort(.notFound))
        }
    }

    enum History {
        struct Record: Codable, Equatable {
            var url: String
            var defaultBranch: String?
            var firstCommitDate: Date?
            var commitCount: Int
            var releaseCount: Int

            enum CodingKeys: String, CodingKey {
                case url
                case defaultBranch = "default_branch"
                case firstCommitDate = "first_commit_date"
                case commitCount = "commit_count"
                case releaseCount = "release_count"
            }

            func history() -> PackageShow.Model.History? {
                guard let defaultBranch = defaultBranch,
                      let firstCommitDate = firstCommitDate else {
                    return nil
                }
                let cl = Link(
                    label: pluralizedCount(commitCount, singular: "commit"),
                    url: url.droppingGitExtension + "/commits/\(defaultBranch)")
                let rl = Link(
                    label: pluralizedCount(releaseCount, singular: "release"),
                    url: url.droppingGitExtension + "/releases")
                return .init(since: "\(inWords: Current.date().timeIntervalSince(firstCommitDate))",
                             commitCount: cl,
                             releaseCount: rl)
            }
        }

        static func query(on database: Database, owner: String, repository: String) -> EventLoopFuture<Record?> {
            guard let db = database as? SQLDatabase else {
                fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
            }
            // This query cannot expressed in Fluent, because it doesn't support
            // GROUP BY clauses.
            return db.raw(#"""
                SELECT p.url, r.default_branch, r.first_commit_date, r.commit_count, count(v.reference) AS "release_count"
                FROM packages p
                JOIN repositories r ON r.package_id = p.id
                LEFT JOIN versions v ON v.package_id = p.id
                    AND v.reference->'tag' IS NOT NULL
                    AND v.reference->'tag'->'semVer'->>'build' = ''
                    AND v.reference->'tag'->'semVer'->>'preRelease' = ''
                WHERE r.owner ILIKE \#(bind: owner)
                AND r.name ILIKE \#(bind: repository)
                GROUP BY p.url, r.default_branch, r.first_commit_date, r.commit_count
                """#)
                .first(decoding: Record.self)
        }
    }

    enum ProductCount {
        static func query(on database: Database, owner: String, repository: String) -> EventLoopFuture<[ProductType]> {
            Joined4<Package, Repository, Version, Product>
                .query(on: database, owner: owner, repository: repository)
                .field(Product.self, \.$type)
                .all()
                .mapEachCompact { $0.product.type }
        }
    }

    struct BuildInfo: Equatable {
        typealias ModelBuildInfo = PackageShow.Model.BuildInfo
        typealias SwiftVersionResults = PackageShow.Model.SwiftVersionResults
        typealias PlatformResults = PackageShow.Model.PlatformResults

        var platform: ModelBuildInfo<PlatformResults>
        var swiftVersion: ModelBuildInfo<SwiftVersionResults>

        static func query(on database: Database, owner: String, repository: String) -> EventLoopFuture<Self> {
            BuildsRoute.BuildInfo.query(on: database, owner: owner, repository: repository)
                .map { builds in
                    Self.init(
                        platform: .init(
                            stable: builds.platformBuildResults(kind: .release),
                            beta: builds.platformBuildResults(kind: .preRelease),
                            latest: builds.platformBuildResults(kind: .defaultBranch)
                        ),
                        swiftVersion: .init(
                            stable: builds.swiftVersionBuildResults(kind: .release),
                            beta: builds.swiftVersionBuildResults(kind: .preRelease),
                            latest: builds.swiftVersionBuildResults(kind: .defaultBranch)
                        )
                    )
                }
        }
    }
}


private extension Array where Element == PackageController.BuildsRoute.BuildInfo {

    var buildStatus: PackageShow.Model.BuildStatus {
        guard !isEmpty else { return .unknown }
        if anySucceeded {
            return .compatible
        } else {
            return anyPending ? .unknown : .incompatible
        }
    }

    typealias NamedBuildResults = PackageShow.Model.NamedBuildResults
    typealias SwiftVersionResults = PackageShow.Model.SwiftVersionResults
    typealias PlatformResults = PackageShow.Model.PlatformResults

    func platformBuildResults(kind: Version.Kind) -> NamedBuildResults<PlatformResults>? {
        let builds = filter { $0.versionKind == kind}
        // builds of the same kind all originate from the same Version via a join,
        // so we can just pick the first one for the reference name
        guard let referenceName = builds.first?.reference.description else {
            return nil
        }
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

    func swiftVersionBuildResults(kind: Version.Kind) -> NamedBuildResults<SwiftVersionResults>? {
        let builds = filter { $0.versionKind == kind}
        // builds of the same kind all originate from the same Version via a join,
        // so we can just pick the first one for the reference name
        guard let referenceName = builds.first?.reference.description else {
            return nil
        }
        // For each reported swift version pick major/minor version matches
        let v5_1 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_1) }
        let v5_2 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_2) }
        let v5_3 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_3) }
        let v5_4 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_4) }
        let v5_5 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_5) }
        // ... and report the status
        return
            .init(referenceName: referenceName,
                  results: .init(status5_1: v5_1.buildStatus,
                                 status5_2: v5_2.buildStatus,
                                 status5_3: v5_3.buildStatus,
                                 status5_4: v5_4.buildStatus,
                                 status5_5: v5_5.buildStatus)
            )
    }

}


extension Array where Element == PackageController.BuildsRoute.BuildInfo {
    var noneSucceeded: Bool {
        allSatisfy { $0.status != .ok }
    }

    var anySucceeded: Bool {
        !noneSucceeded
    }

    var nonePending: Bool {
        allSatisfy { $0.status.isCompleted }
    }

    var anyPending: Bool {
        !nonePending
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


extension PackageController.PackageResult {
    var package: Package { model }
    // We can force-unwrap due to the inner join
    var repository: Repository { relation1! }
    // We can force-unwrap due to the inner join
    var defaultBranchVersion: DefaultVersion { relation2! }
    var releaseVersion: ReleaseVersion? { relation3 }
    var preReleaseVersion: PreReleaseVersion? { relation4 }

    @available(*, deprecated)
    var versions: [Version] {
        [defaultBranchVersion.model, releaseVersion?.model, preReleaseVersion?.model].compactMap { $0 }
    }

    static func query(on database: Database, owner: String, repository: String) -> EventLoopFuture<Self> {
        Package.query(on: database)
            .join(Repository.self,
                  on: \Repository.$package.$id == \Package.$id,
                  method: .inner)
            .join(DefaultVersion.self,
                  on: \DefaultVersion.$package.$id == \Package.$id,
                  method: .inner)
            .join(Package.self, ReleaseVersion.self,
                  on: .custom(#"""
                    LEFT JOIN "\#(Version.schema)" AS "\#(ReleaseVersion.name)"
                    ON "\#(Package.schema)"."id" = "\#(ReleaseVersion.name)"."package_id"
                    AND "\#(ReleaseVersion.name)"."latest" = 'release'
                    """#)
            )
            .join(Package.self, PreReleaseVersion.self,
                  on: .custom(#"""
                    LEFT JOIN "\#(Version.schema)" AS "\#(PreReleaseVersion.name)"
                    ON "\#(Package.schema)"."id" = "\#(PreReleaseVersion.name)"."package_id"
                    AND "\#(PreReleaseVersion.name)"."latest" = 'pre_release'
                    """#)
            )
            .filter(Repository.self, \.$owner, .custom("ilike"), owner)
            .filter(Repository.self, \.$name, .custom("ilike"), repository)
            .filter(DefaultVersion.self, \.$latest == .defaultBranch)
        // TODO: only load required fields
            .first()
            .unwrap(or: Abort(.notFound))
            .map(Self.init(model:))
    }
}


final class DefaultVersion: ModelAlias {
    static let name = "default_version"
    let model = Version()

    #warning("temp. to make it compile")
    var products: [Product] { [] }
}

final class ReleaseVersion: ModelAlias {
    static let name = "release_version"
    let model = Version()
}

final class PreReleaseVersion: ModelAlias {
    static let name = "pre_release_version"
    let model = Version()
}


extension PackageController {
    enum BuildsRoute {
        struct PackageInfo: Equatable {
            var packageName: String?
            var repositoryOwner: String
            var repositoryName: String

            static func query(on database: Database, owner: String, repository: String) -> EventLoopFuture<(PackageInfo)> {
                Joined3<Package, Repository, Version>
                    .query(on: database, owner: owner, repository: repository, version: .defaultBranch)
                    .field(Repository.self, \.$owner)
                    .field(Repository.self, \.$name)
                    .field(Version.self, \.$packageName)
                    .first()
                    .unwrap(or: Abort(.notFound))
                    .flatMapThrowing { model in
                        let repo = model.repository
                        guard let repoOwner = repo.owner,
                              let repoName = repo.name else {
                                  throw Abort(.notFound)
                              }
                        return .init(packageName: model.version.packageName,
                                     repositoryOwner: repoOwner,
                                     repositoryName: repoName)
                    }
            }
        }

        struct BuildInfo: Equatable {
            var versionKind: Version.Kind
            var reference: Reference
            var buildId: Build.Id
            var swiftVersion: SwiftVersion
            var platform: Build.Platform
            var status: Build.Status

            static func query(on database: Database, owner: String, repository: String) -> EventLoopFuture<[BuildInfo]> {
                Joined4<Build, Version, Package, Repository>
                    .query(on: database)
                    .filter(Version.self, \Version.$latest != nil)
                    .filter(Repository.self, \.$owner, .custom("ilike"), owner)
                    .filter(Repository.self, \.$name, .custom("ilike"), repository)
                    .field(\.$id)
                    .field(\.$swiftVersion)
                    .field(\.$platform)
                    .field(\.$status)
                    .field(Version.self, \.$latest)
                    .field(Version.self, \.$packageName)
                    .field(Version.self, \.$reference)
                    .all()
                    .flatMapThrowing { results in
                        try results
                            .compactMap { res -> BuildInfo? in
                                let build = res.build
                                let version = res.version
                                guard let kind = version.latest,
                                      let reference = version.reference else {
                                          return nil
                                      }
                                return try BuildInfo(versionKind: kind,
                                                     reference: reference,
                                                     buildId: build.requireID(),
                                                     swiftVersion: build.swiftVersion,
                                                     platform: build.platform,
                                                     status: build.status)
                            }
                    }
            }
        }

        static func query(on database: Database, owner: String, repository: String) -> EventLoopFuture<(PackageInfo, [BuildInfo])> {
            PackageInfo.query(on: database, owner: owner, repository: repository)
                .and(BuildInfo.query(on: database, owner: owner, repository: repository))
        }
    }
}
