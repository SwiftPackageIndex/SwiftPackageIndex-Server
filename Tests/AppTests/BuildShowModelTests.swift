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

@testable import App

import Testing
import Vapor


extension AllTests.BuildShowModelTests {

    typealias Model = BuildShow.Model

    @Test func buildsURL() throws {
        #expect(Model.mock.buildsURL == "/foo/bar/builds")
    }

    @Test func packageURL() throws {
        #expect(Model.mock.packageURL == "/foo/bar")
    }

    @Test func Model_init() async throws {
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "1".url)
            try await Repository(package: pkg,
                                 defaultBranch: "main",
                                 forks: 42,
                                 license: .mit,
                                 name: "bar",
                                 owner: "foo",
                                 stars: 17,
                                 summary: "summary").save(on: app.db)
            let version = try Version(id: UUID(), package: pkg, packageName: "Bar", reference: .branch("main"))
            try await version.save(on: app.db)
            let buildId = UUID()
            try await Build(id: buildId, version: version, platform: .iOS, status: .ok, swiftVersion: .v3)
                .save(on: app.db)
            let result = try await BuildResult.query(on: app.db, buildId: buildId)
            
            // MUT
            let model = BuildShow.Model(result: result, logs: "logs")
            
            // validate
            #expect(model?.packageName == "Bar")
            #expect(model?.versionId == version.id)
            #expect(model?.buildInfo.logs == "logs")
        }
    }

}
