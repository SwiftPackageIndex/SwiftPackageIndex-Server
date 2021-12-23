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
                .map { (packageResult, historyResult) -> (model: PackageShow.Model, schema: PackageShow.PackageSchema)? in
                    guard let model = PackageShow.Model(result: packageResult,
                                                        history: historyResult?.history()),
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
        struct Record: Codable {
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
