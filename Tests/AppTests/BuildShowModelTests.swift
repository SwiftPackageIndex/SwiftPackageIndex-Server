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

@testable import App

import XCTVapor


// FIXME: rename
class BuildShowModelTests: AppTestCase {

    func test_buildsURL() throws {
        XCTAssertEqual(Model.mock.buildsURL, "/foo/bar/builds")
    }

    func test_packageURL() throws {
        XCTAssertEqual(Model.mock.packageURL, "/foo/bar")
    }

    func test_query() throws {
        // Tests BuildResult.query as it is used in BuildController by validating
        // packageName. This property requires relations to be fully loaded,
        // which is what Build.query is taking care of.
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
        let v = try Version(id: UUID(), package: pkg, packageName: "Bar", reference: .branch("main"))
        try v.save(on: app.db).wait()
        let buildId = UUID()
        let build = try Build(id: buildId, version: v, platform: .ios, status: .ok, swiftVersion: .init(5, 3, 0))
        try build.save(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: pkg.id!).wait()
        // update versions
        try updateLatestVersions(on: app.db, package: jpr).wait()

        // MUT
        let m = try BuildController.BuildResult
            .query(on: app.db, buildId: buildId)
            .flatMap { result in
                Build.fetchLogs(client: self.app.client, logUrl: result.build.logUrl)
                    .map { (result, $0) }
            }
            .map(BuildShow.Model.init(result:logs:))
            .wait()

        // validate
        XCTAssertEqual(m?.packageName, "Bar")
    }

}


fileprivate typealias Model = BuildShow.Model
