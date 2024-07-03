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

enum BuildMonitorController {
    static func index(req: Request) async throws -> HTML {
        let builds = try await BuildResult.query(on: req.db)
            .field(Build.self, \.$id)
            .field(Build.self, \.$createdAt)
            .field(Build.self, \.$platform)
            .field(Build.self, \.$swiftVersion)
            .field(Build.self, \.$status)
            .field(Version.self, \.$packageName)
            .field(Version.self, \.$reference)
            .field(Version.self, \.$latest)
            .field(Repository.self, \.$name)
            .field(Repository.self, \.$owner)
            .field(Repository.self, \.$ownerName)
            .sort(\.$createdAt, .descending)
            .limit(200)
            .all()
            .compactMap(BuildMonitorIndex.Model.init(buildResult:))

        return BuildMonitorIndex.View(path: req.url.path, builds: builds)
                    .document()
    }
}
