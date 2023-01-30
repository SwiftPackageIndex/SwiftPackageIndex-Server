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
import PostgresKit
import Vapor


extension API {
    
    enum BuildController {
        static func buildReport(req: Request) async throws -> HTTPStatus {
            let dto = try req.content.decode(PostCreateBuildDTO.self)
            let version = try await App.Version
                .find(req.parameters.get("id"), on: req.db)
                .unwrap(or: Abort(.notFound))

            do {  // update build
                  // Find or create build for updating.
                  // We look up by default, because the common case is that a build stub
                  // is present.
                let build = try await Build.query(on: req.db,
                                                  platform: dto.platform,
                                                  swiftVersion: dto.swiftVersion,
                                                  versionId: version.requireID())
                ?? Build(version: version,
                         platform: dto.platform,
                         status: dto.status,
                         swiftVersion: dto.swiftVersion)
                build.buildCommand = dto.buildCommand
                build.jobUrl = dto.jobUrl
                build.logUrl = dto.logUrl
                build.platform = dto.platform
                build.runnerId = dto.runnerId
                build.status = dto.status
                build.swiftVersion = dto.swiftVersion
                do {
                    try await build.save(on: req.db)
                } catch {
                    // We could simply let this propagate but this is easier to diagnose
                    // (although it should technically be impossible to actually occur
                    // since we are explicitly querying for the record to update rather
                    // than saving without checking for conflict first.)
                    if let error = error as? PostgresError,
                       error.code == .uniqueViolation {
                        return .conflict
                    } else {
                        throw error
                    }
                }

                AppMetrics.apiBuildReportTotal?.inc(1, .buildReportLabels(build))
                if build.status == .infrastructureError {
                    req.logger.critical("build infrastructure error: \(build.jobUrl)")
                }
            }

            do {  // update version and package
                var needsSave = false
                if let dependencies = dto.resolvedDependencies {
                    version.resolvedDependencies = dependencies
                    needsSave = true
                }
                if let docArchives = dto.docArchives {
                    version.docArchives = docArchives
                    needsSave = true
                }
                if needsSave { try await version.save(on: req.db) }

                // it's ok to reach through $package to get its id, because `$package.id`
                // is actually `versions.package_id` and therefore loaded
                try await Package
                    .updatePlatformCompatibility(for: version.$package.id, on: req.db)
            }

            return .noContent
        }

        static func trigger(req: Request) throws -> EventLoopFuture<Build.TriggerResponse> {
            guard let id = req.parameters.get("id"),
                  let versionId = UUID(uuidString: id)
            else {
                return req.eventLoop.future(error: Abort(.badRequest))
            }
            let dto = try req.content.decode(PostBuildTriggerDTO.self)
            return Build.trigger(database: req.db,
                                 client: req.client,
                                 logger: req.logger,
                                 buildId: .init(),
                                 platform: dto.platform,
                                 swiftVersion: dto.swiftVersion,
                                 versionId: versionId)
        }
    }

}
