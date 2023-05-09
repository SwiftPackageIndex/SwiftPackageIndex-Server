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

import DependencyResolution
import Fluent
import SQLKit
import Vapor


extension API.PackageController {
    typealias PackageResult = Joined5<Package, Repository, DefaultVersion, ReleaseVersion, PreReleaseVersion>

    enum GetRoute {

        /// Assembles individual queries and transforms them into model structs.
        /// - Parameters:
        ///   - database: `Database`
        ///   - owner: repository owner
        ///   - repository: repository name
        /// - Returns: model structs
        static func query(on database: Database, owner: String, repository: String) async throws -> (model: Model, schema: API.PackageSchema) {
            let packageResult = try await PackageResult.query(on: database,
                                                              owner: owner,
                                                              repository: repository)
            async let weightedKeywords = WeightedKeyword.query(
                on: database, keywords: packageResult.repository.keywords
            )
            async let historyRecord = Self.History.query(on: database,
                                                    owner: owner,
                                                    repository: repository)
            async let productTypes = Self.ProductCount.query(on: database,
                                                        owner: owner,
                                                        repository: repository)
            async let buildInfo = Self.BuildInfo.query(on: database,
                                                  owner: owner,
                                                  repository: repository)

            guard
                let model = try await Self.Model(
                    result: packageResult,
                    history: historyRecord?.historyModel(),
                    productCounts: .init(
                        libraries: productTypes.filter(\.isLibrary).count,
                        executables: productTypes.filter(\.isExecutable).count,
                        plugins: productTypes.filter(\.isPlugin).count),
                    swiftVersionBuildInfo: buildInfo.swiftVersion,
                    platformBuildInfo: buildInfo.platform,
                    weightedKeywords: weightedKeywords
                ),
                let schema = API.PackageSchema(result: packageResult)
            else {
                throw Abort(.notFound)
            }

            return (model, schema)
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

                func historyModel() -> GetRoute.Model.History? {
                    guard let defaultBranch = defaultBranch,
                          let firstCommitDate = firstCommitDate else {
                        return nil
                    }
                    let cl = Link(
                        label: commitCount.labeled("commit"),
                        url: url.droppingGitExtension + "/commits/\(defaultBranch)")
                    let rl = Link(
                        label: releaseCount.labeled("release"),
                        url: url.droppingGitExtension + "/releases")
                    return .init(since: "\(inWords: Current.date().timeIntervalSince(firstCommitDate))",
                                 commitCount: cl,
                                 releaseCount: rl)
                }
            }

            static func query(on database: Database, owner: String, repository: String) async throws -> Record? {
                guard let db = database as? SQLDatabase else {
                    fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
                }
                // This query cannot expressed in Fluent, because it doesn't support
                // GROUP BY clauses.
                return try await db.raw(#"""
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
            static func query(on database: Database, owner: String, repository: String) async throws -> [ProductType] {
                try await Joined4<Package, Repository, Version, Product>
                    .query(on: database, owner: owner, repository: repository)
                    .field(Product.self, \.$type)
                    .all()
                    .compactMap(\.product.type)
            }
        }

        struct BuildInfo: Equatable {
            typealias ModelBuildInfo = GetRoute.Model.BuildInfo
            typealias NamedBuildResults = GetRoute.Model.NamedBuildResults
            typealias PlatformResults = GetRoute.Model.PlatformResults
            typealias SwiftVersionResults = GetRoute.Model.SwiftVersionResults

            var platform: ModelBuildInfo<PlatformResults>?
            var swiftVersion: ModelBuildInfo<SwiftVersionResults>?

            static func query(on database: Database, owner: String, repository: String) async throws -> Self {
                // FIXME: move up from PackageController.BuildsRoute into API.PackageController.BuildsRoute
                let builds = try await PackageController.BuildsRoute.BuildInfo.query(on: database,
                                                                   owner: owner,
                                                                   repository: repository)
                return Self.init(
                    platform: platformBuildInfo(builds: builds),
                    swiftVersion: swiftVersionBuildInfo(builds: builds)
                )
            }

            static func platformBuildInfo(
                builds: [PackageController.BuildsRoute.BuildInfo]
            ) -> ModelBuildInfo<PlatformResults>? {
                .init(stable: platformBuildResults(builds: builds,
                                                   kind: .release),
                      beta: platformBuildResults(builds: builds,
                                                 kind: .preRelease),
                      latest: platformBuildResults(builds: builds,
                                                   kind: .defaultBranch))
            }

            static func platformBuildResults(
                builds: [PackageController.BuildsRoute.BuildInfo],
                kind: Version.Kind
            ) -> NamedBuildResults<PlatformResults>? {
                let builds = builds.filter { $0.versionKind == kind}
                // builds of the same kind all originate from the same Version via a join,
                // so we can just pick the first one for the reference name
                guard let referenceName = builds.first?.reference.description else {
                    return nil
                }
                // For each reported platform pick appropriate build matches
                let ios = builds.filter { $0.platform.isCompatible(with: .ios) }
                let linux = builds.filter { $0.platform.isCompatible(with: .linux) }
                let macos = builds.filter { $0.platform.isCompatible(with: .macos) }
                let tvos = builds.filter { $0.platform.isCompatible(with: .tvos) }
                let watchos = builds.filter { $0.platform.isCompatible(with: .watchos) }
                // ... and report the status
                return
                    .init(referenceName: referenceName,
                          results: .init(iosStatus: ios.buildStatus,
                                         linuxStatus: linux.buildStatus,
                                         macosStatus: macos.buildStatus,
                                         tvosStatus: tvos.buildStatus,
                                         watchosStatus: watchos.buildStatus)
                    )
            }

            static func swiftVersionBuildInfo(
                builds: [PackageController.BuildsRoute.BuildInfo]
            ) -> ModelBuildInfo<SwiftVersionResults>? {
                .init(stable: swiftVersionBuildResults(builds: builds,
                                                       kind: .release),
                      beta: swiftVersionBuildResults(builds: builds,
                                                     kind: .preRelease),
                      latest: swiftVersionBuildResults(builds: builds,
                                                       kind: .defaultBranch))
            }

            static func swiftVersionBuildResults(
                builds: [PackageController.BuildsRoute.BuildInfo],
                kind: Version.Kind
            ) -> NamedBuildResults<SwiftVersionResults>? {
                let builds = builds.filter { $0.versionKind == kind}
                // builds of the same kind all originate from the same Version via a join,
                // so we can just pick the first one for the reference name
                guard let referenceName = builds.first?.reference.description else {
                    return nil
                }
                // For each reported swift version pick major/minor version matches
                let v5_5 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_5) }
                let v5_6 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_6) }
                let v5_7 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_7) }
                let v5_8 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_8) }
                // ... and report the status
                return
                    .init(referenceName: referenceName,
                          results: .init(status5_5: v5_5.buildStatus,
                                         status5_6: v5_6.buildStatus,
                                         status5_7: v5_7.buildStatus,
                                         status5_8: v5_8.buildStatus)
                    )
            }
        }

    }

}


extension API.PackageController.PackageResult {

    func authors() -> AuthorMetadata? {
        if let spiManifest = defaultBranchVersion.spiManifest,
           let metadata = spiManifest.metadata,
           let authors = metadata.authors {
            return AuthorMetadata.fromSPIManifest(authors)
        } else if let authors = repository.authors {
            return AuthorMetadata.fromGitRepository(authors)
        } else {
            return nil
        }
    }

    func activity() -> API.PackageController.GetRoute.Model.Activity? {
        guard repository.lastPullRequestClosedAt != nil else { return nil }

        let openIssues = Link(label: repository.openIssues.labeled("open issue"),
                              url: package.url.droppingGitExtension + "/issues")
        let openPRs = Link(label: repository.openPullRequests.labeled("open pull request"),
                           url: package.url.droppingGitExtension + "/pulls")
        let lastIssueClosed = repository.lastIssueClosedAt.map { "\(date: $0, relativeTo: Current.date())" }
        let lastPRClosed = repository.lastPullRequestClosedAt.map { "\(date: $0, relativeTo: Current.date())" }
        return .init(openIssuesCount: repository.openIssues,
                     openIssues: openIssues,
                     openPullRequests: openPRs,
                     lastIssueClosedAt: lastIssueClosed,
                     lastPullRequestClosedAt: lastPRClosed)
    }

}


extension API.PackageController.GetRoute {
    static func releaseInfo(packageUrl: String,
                            defaultBranchVersion: DefaultVersion?,
                            releaseVersion: ReleaseVersion?,
                            preReleaseVersion: PreReleaseVersion?) -> Self.Model.ReleaseInfo {
        let links = [releaseVersion?.model, preReleaseVersion?.model, defaultBranchVersion?.model]
            .map { version -> DatedLink? in
                guard let version = version else { return nil }
                return makeDatedLink(packageUrl: packageUrl,
                                     version: version,
                                     keyPath: \.commitDate)
            }
        return .init(stable: links[0],
                     beta: links[1],
                     latest: links[2])
    }
}
