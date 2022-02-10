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


extension API {
    
    struct BuildController {
        func create(req: Request) throws -> EventLoopFuture<Build> {
            let dto = try req.content.decode(PostCreateBuildDTO.self)
            return App.Version.find(req.parameters.get("id"), on: req.db)
                .unwrap(or: Abort(.notFound))
                .flatMap { version in
                    guard let dependencies = dto.resolvedDependencies else {
                        return req.eventLoop.future(version)
                    }
                    version.resolvedDependencies = dependencies
                    return version.save(on: req.db)
                        .transform(to: version)
                }
                .flatMapThrowing { ($0, try Build(dto, $0)) }
                .flatMap { (version, build) -> EventLoopFuture<(App.Version, Build)> in
                    AppMetrics.apiBuildReportTotal?.inc(1, .init(build.platform,
                                                                 build.runnerId ?? "",
                                                                 build.swiftVersion))
                    if build.status == .infrastructureError {
                        req.logger.critical("build infrastructure error: \(build.jobUrl)")
                    }
                    return build.upsert(on: req.db).transform(to: (version, build))
                }
                .flatMap { (version, build) in
                    Package.find(version.$package.id, on: req.db)
                        .flatMap { package -> EventLoopFuture<Void> in
                            guard let package = package else {
                                return req.eventLoop.future()
                            }
                            return package.updatePlatformCompatibility(on: req.db)
                        }
                        .transform(to: build)
                }
        }
        
        func trigger(req: Request) throws -> EventLoopFuture<Build.TriggerResponse> {
            guard let id = req.parameters.get("id"),
                  let versionId = UUID(uuidString: id) else {
                return req.eventLoop.future(error: Abort(.badRequest))
            }
            let dto = try req.content.decode(PostBuildTriggerDTO.self)
            return Build.trigger(database: req.db,
                                 client: req.client,
                                 platform: dto.platform,
                                 swiftVersion: dto.swiftVersion,
                                 versionId: versionId)
        }

        func updateBuild(req: Request) async throws -> HTTPStatus {
            let dto = try req.content.decode(PostCreateBuildDTO.self)
            guard let buildId = req.parameters.get("id").map(UUID.init(uuidString:)),
                  let versionId = dto.versionId else {
                      throw Abort(.badRequest)
                  }

            do {  // update build
                let build = try await Build.find(buildId, on: req.db)
                ?? Build(id: buildId,
                         versionId: versionId,
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
                try await build.save(on: req.db)
            }

            do {  // update version and package
                let version = try await App.Version
                    .find(dto.versionId, on: req.db)
                    .unwrap(or: Abort(.notFound))
                if let dependencies = dto.resolvedDependencies {
                    version.resolvedDependencies = dependencies
                    try await version.save(on: req.db)
                }

                try await Package
                    .updatePlatformCompatibility(for: version.$package.id, on: req.db)
            }

            return .noContent
        }
    }

}
