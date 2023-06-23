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

import XCTVapor


class BuildShowModelTests: AppTestCase {

    typealias Model = BuildShow.Model

    func test_buildsURL() throws {
        XCTAssertEqual(Model.mock.buildsURL, "/foo/bar/builds")
    }

    func test_packageURL() throws {
        XCTAssertEqual(Model.mock.packageURL, "/foo/bar")
    }

    func test_init() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1".url)
        try Repository(package: pkg,
                       defaultBranch: "main",
                       forks: 42,
                       license: .mit,
                       name: "bar",
                       owner: "foo",
                       stars: 17,
                       summary: "summary").save(on: app.db).wait()
        let version = try Version(id: UUID(), package: pkg, packageName: "Bar", reference: .branch("main"))
        try version.save(on: app.db).wait()
        let buildId = UUID()
        try Build(id: buildId, version: version, platform: .iOS, status: .ok, swiftVersion: .v3)
            .save(on: app.db).wait()
        let result = try BuildResult
            .query(on: app.db, buildId: buildId)
            .wait()

        // MUT
        let model = BuildShow.Model(result: result, logs: "logs")

        // validate
        XCTAssertEqual(model?.packageName, "Bar")
        XCTAssertEqual(model?.versionId, version.id)
        XCTAssertEqual(model?.buildInfo.logs, "logs")
    }

}
