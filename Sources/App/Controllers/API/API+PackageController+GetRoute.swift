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
            async let productTypes = API.PackageController.ProductCount.query(on: database,
                                                                              owner: owner,
                                                                              repository: repository)
            async let buildInfo = API.PackageController.BuildInfo.query(on: database,
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
