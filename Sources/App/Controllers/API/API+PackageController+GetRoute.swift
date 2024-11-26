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

import Dependencies
import DependencyResolution
import Fluent
import Vapor


extension API.PackageController {
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
            async let historyRecord = API.PackageController.History.query(on: database,
                                                                          owner: owner,
                                                                          repository: repository)
            async let products = API.PackageController.Product.query(on: database,
                                                                     owner: owner,
                                                                     repository: repository)
            async let targets = API.PackageController.Target.query(on: database,
                                                                   owner: owner,
                                                                   repository: repository)
            async let buildInfo = API.PackageController.BuildInfo.query(on: database,
                                                                        owner: owner,
                                                                        repository: repository)
            async let forkedFromInfo = forkedFromInfo(on: database, fork: packageResult.repository.forkedFrom)

            async let customCollections = customCollections(on: database, package: packageResult.package)

            guard
                let model = try await Self.Model(
                    result: packageResult,
                    history: historyRecord?.historyModel(),
                    products: products.compactMap(Model.Product.init(name:productType:)),
                    targets: targets.compactMap(Model.Target.init(name:targetType:)),
                    swiftVersionBuildInfo: buildInfo.swiftVersion,
                    platformBuildInfo: buildInfo.platform,
                    weightedKeywords: weightedKeywords,
                    swift6Readiness: buildInfo.swift6Readiness,
                    forkedFromInfo: forkedFromInfo,
                    customCollections: customCollections
                ),
                let schema = API.PackageSchema(result: packageResult)
            else {
                throw Abort(.notFound)
            }

            return (model, schema)
        }
    }
}


extension API.PackageController.GetRoute {
    static func releaseInfo(packageUrl: String,
                            defaultBranchVersion: DefaultVersion?,
                            releaseVersion: ReleaseVersion?,
                            preReleaseVersion: PreReleaseVersion?) -> Self.Model.ReleaseInfo {
        let links = [releaseVersion?.model, preReleaseVersion?.model, defaultBranchVersion?.model]
            .map { version -> DateLink? in
                guard let version = version else { return nil }
                return makeDateLink(packageUrl: packageUrl,
                                    version: version,
                                    keyPath: \.commitDate)
            }
        return .init(stable: links[0],
                     beta: links[1],
                     latest: links[2])
    }

    static func forkedFromInfo(on database: Database, fork: Fork?) async -> Model.ForkedFromInfo? {
        guard let forkedFrom = fork else { return nil }
        switch forkedFrom {
            case .parentId(let id, let fallbackURL):
                return await Model.ForkedFromInfo.query(on: database, packageId: id, fallbackURL: fallbackURL)
            case let .parentURL(url):
                return .fromGitHub(url: url)
        }
    }

    static func customCollections(on database: Database, package: Package) async -> [CustomCollection.Details] {
        @Dependency(\.environment) var environment
        guard environment.current() == .development else { return [] }
        do {
            try await package.$customCollections.load(on: database)
            return package.customCollections.map(\.details)
        } catch {
            return []
        }
    }
}


extension API.PackageController.GetRoute.Model.ForkedFromInfo {
    static func query(on database: Database, packageId: Package.Id, fallbackURL: String) async -> Self? {
        let model = try? await Joined3<Package, Repository, Version>
            .query(on: database, packageId: packageId, version: .defaultBranch)
            .first()

        guard let repoName = model?.repository.name,
              let ownerName = model?.repository.ownerName,
              let owner = model?.repository.owner else {
            return .fromGitHub(url: fallbackURL)
        }

        return .fromSPI(originalOwner: owner,
                        originalOwnerName: ownerName,
                        originalRepo: repoName,
                        originalPackageName: model?.version.packageName ?? repoName)
    }
}
