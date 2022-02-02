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
import Plot
import Vapor


struct BuildController {
    func show(req: Request) throws -> EventLoopFuture<HTML> {
        guard let id = req.parameters.get("id"),
              let buildId = UUID.init(uuidString: id)
        else { return req.eventLoop.future(error: Abort(.notFound)) }

        return BuildResult.query(on: req.db, buildId: buildId)
            .flatMap { result in
                Build.fetchLogs(client: req.client, logUrl: result.build.logUrl)
                    .map { (result, $0) }
            }
            .map(BuildShow.Model.init(result:logs:))
            .unwrap(or: Abort(.notFound))
            .map {
                BuildShow.View(path: req.url.path, model: $0).document()
            }
    }

}
