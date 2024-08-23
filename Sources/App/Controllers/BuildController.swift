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
import Plot
import Vapor


enum BuildController {
    @Sendable
    static func show(req: Request) async throws -> HTML {
        guard let id = req.parameters.get("id"),
              let buildId = UUID.init(uuidString: id)
        else { throw Abort(.notFound) }

        let result = try await BuildResult.query(on: req.db, buildId: buildId)
        let logs = try await Build.fetchLogs(client: req.client, logUrl: result.build.logUrl)
        guard let model = BuildShow.Model(result: result, logs: logs) else { throw Abort(.notFound) }
        return BuildShow.View(path: req.url.path, model: model).document()
    }

}
