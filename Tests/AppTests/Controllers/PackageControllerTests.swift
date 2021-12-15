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

import Vapor
import XCTest

class PackageControllerTests: AppTestCase {

    func test_show_owner_repository() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db).wait()

        // MUT
        try app.test(.GET, "/owner/package", afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
        })
    }

    func test_BuildsRoute_query() throws {
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
        let v = try Version(package: pkg, latest: .defaultBranch, packageName: "pkg", reference: .branch("main"))
        try v.save(on: app.db).wait()
        try Build(id: .id0, version: v, platform: .ios, status: .ok, swiftVersion: .v5_5)
            .save(on: app.db).wait()

        // MUT
        let (pkgInfo, buildInfo) = try PackageController.BuildsRoute
            .query(on: app.db, owner: "foo", repository: "bar").wait()

        // validate
        XCTAssertEqual(pkgInfo, .init(packageName: "pkg",
                                      repositoryOwner: "foo",
                                      repositoryName: "bar"))
        XCTAssertEqual(buildInfo, [
            .init(versionKind: .defaultBranch,
                  reference: .branch("main"),
                  buildId: .id0,
                  swiftVersion: .v5_5,
                  platform: .ios,
                  status: .ok)
        ])
    }

    func test_BuildsRoute_query_no_builds() throws {
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
        // no builds and also no packageName set
        try Version(package: pkg, latest: .defaultBranch, packageName: nil).save(on: app.db).wait()

        // MUT
        let (pkgInfo, buildInfo) = try PackageController.BuildsRoute
            .query(on: app.db, owner: "foo", repository: "bar").wait()

        // validate
        XCTAssertEqual(pkgInfo, .init(packageName: nil,
                                      repositoryOwner: "foo",
                                      repositoryName: "bar"))
        XCTAssertEqual(buildInfo, [])

    }

}
