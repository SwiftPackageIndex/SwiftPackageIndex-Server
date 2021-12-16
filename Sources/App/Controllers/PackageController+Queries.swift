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
import Vapor


extension PackageController {
    //    (Package - Repository) -< Version
    //                                 |
    //                                 |-< Build
    //                                 |
    //                                 '-< Product
    typealias PackageResult = Ref<Joined<Package, Repository>, Ref2<Version, Build, Product>>

    enum ShowRoute {
        static func query(on database: Database, owner: String, repository: String) -> EventLoopFuture<(model: PackageShow.Model, schema: PackageShow.PackageSchema)> {
            PackageResult.query(on: database, owner: owner, repository: repository)
                .map { result -> (model: PackageShow.Model, schema: PackageShow.PackageSchema)? in
                    guard
                        let model = PackageShow.Model(result: result),
                        let schema = PackageShow.PackageSchema(result: result)
                    else {
                        return nil
                    }

                    return (model, schema)
                }
                .unwrap(or: Abort(.notFound))
        }
    }
}


extension PackageController.PackageResult {
    var package: Package { model.package }
    // We can safely force-unwrap model.repository because it's a relation from
    // an INNER query.
    var repository: Repository { model.repository! }
    var versions: [Version] { package.versions }

    static func query(on database: Database, owner: String, repository: String) -> EventLoopFuture<Self> {
        Joined<Package, Repository>.query(on: database)
            .with(\.$versions) {
                $0.with(\.$products)
                $0.with(\.$builds)
            }
            .filter(Repository.self, \.$owner, .custom("ilike"), owner)
            .filter(Repository.self, \.$name, .custom("ilike"), repository)
            .first()
            .unwrap(or: Abort(.notFound))
            .map(Self.init(model:))
    }
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
