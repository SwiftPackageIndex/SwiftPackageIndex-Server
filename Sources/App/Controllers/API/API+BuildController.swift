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
                .flatMapThrowing { try Build(dto, $0) }
                .flatMap { build in
                    AppMetrics.apiBuildReportTotal?.inc(1, .init(build.platform, build.swiftVersion))
                    if build.status == .infrastructureError {
                        req.logger.critical("build infrastructure error: \(build.jobUrl)")
                    }
                    return build.upsert(on: req.db).transform(to: build)
                }
        }
        
        func trigger(req: Request) throws -> EventLoopFuture<HTTPStatus> {
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
    }
    
}
