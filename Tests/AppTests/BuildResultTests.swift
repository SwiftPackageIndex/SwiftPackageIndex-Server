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


class BuildResultTests: AppTestCase {

    func test_query() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1".url)
        let repo = try Repository(package: pkg)
        try repo.save(on: app.db).wait()
        let version = try Version(package: pkg)
        try version.save(on: app.db).wait()
        let build = try Build(version: version, platform: .ios, status: .ok, swiftVersion: .init(5, 3, 0))
        try build.save(on: app.db).wait()

        // MUT
        let res = try BuildResult
            .query(on: app.db, buildId: build.id!)
            .wait()

        // validate
        XCTAssertEqual(res.build.id, build.id)
        XCTAssertEqual(res.package.id, pkg.id)
        XCTAssertEqual(res.repository.id, repo.id)
        XCTAssertEqual(res.version.id, version.id)
    }

}
