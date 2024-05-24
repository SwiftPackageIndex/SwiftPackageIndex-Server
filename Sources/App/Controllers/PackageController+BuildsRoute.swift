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

import Fluent
import Vapor


extension PackageController {
    // TODO: move to API.PackageController
    enum BuildsRoute {
        struct PackageInfo: Equatable {
            var packageName: String?
            var repositoryOwner: String
            var repositoryOwnerName: String?
            var repositoryName: String

            static func query(on database: Database, owner: String, repository: String) async throws -> PackageInfo {
                let model = try await Joined3<Package, Repository, Version>
                    .query(on: database, owner: owner, repository: repository, version: .defaultBranch)
                    .field(Repository.self, \.$owner)
                    .field(Repository.self, \.$ownerName)
                    .field(Repository.self, \.$name)
                    .field(Version.self, \.$packageName)
                    .first()
                    .unwrap(or: Abort(.notFound))
                let repo = model.repository
                guard let repoOwner = repo.owner,
                      let repoName = repo.name else {
                    throw Abort(.notFound)
                }
                return .init(packageName: model.version.packageName,
                             repositoryOwner: repoOwner,
                             repositoryOwnerName: repo.ownerName,
                             repositoryName: repoName)
            }
        }

        struct BuildInfo: Equatable {
            var versionKind: Version.Kind
            var reference: Reference
            var buildId: Build.Id
            var swiftVersion: SwiftVersion
            var platform: Build.Platform
            var status: Build.Status
            var docStatus: DocUpload.Status?
            var buildErrors: BuildErrors?

            static func query(on database: Database, owner: String, repository: String) async throws -> [BuildInfo] {
                try await Joined5<Build, Version, Package, Repository, DocUpload>
                    .query(on: database, owner: owner, repository: repository)
                    .field(\.$id)
                    .field(\.$swiftVersion)
                    .field(\.$platform)
                    .field(\.$status)
                    .field(\.$buildErrors)
                    .field(Version.self, \.$latest)
                    .field(Version.self, \.$packageName)
                    .field(Version.self, \.$reference)
                    .field(DocUpload.self, \.$status)
                    .all()
                    .compactMap { res -> BuildInfo? in
                        let build = res.build
                        let version = res.version
                        guard let kind = version.latest else {
                            return nil
                        }
                        return try BuildInfo(versionKind: kind,
                                             reference: version.reference,
                                             buildId: build.requireID(),
                                             swiftVersion: build.swiftVersion,
                                             platform: build.platform,
                                             status: build.status,
                                             docStatus: res.docUpload?.status,
                                             buildErrors: build.buildErrors)
                    }
            }
        }

        static func query(on database: Database, owner: String, repository: String) async throws -> (PackageInfo, [BuildInfo]) {
            async let packageInfo = PackageInfo.query(on: database,
                                                      owner: owner,
                                                      repository: repository)
            async let buildInfo = BuildInfo.query(on: database,
                                                  owner: owner,
                                                  repository: repository)
            return try await (packageInfo, buildInfo)
        }
    }
}
