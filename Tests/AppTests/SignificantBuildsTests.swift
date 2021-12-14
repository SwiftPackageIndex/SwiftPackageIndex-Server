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

import XCTest


class SignificantBuildsTests: AppTestCase {

    func test_swiftVersionCompatibility() throws {
        // setup
        let sb = SignificantBuilds(builds: [
            .init(.ok, .linux, .v5_3),
            .init(.ok, .macosXcodebuild, .v5_2),
            .init(.failed, .ios, .v5_1)
        ])

        // MUT
        let res = try XCTUnwrap(sb.swiftVersionCompatibility().values)

        // validate
        XCTAssertEqual(res.sorted(), [.v5_2, .v5_3])
    }

    func test_swiftVersionCompatibility_allPending() throws {
        // setup
        let sb = SignificantBuilds(builds: [
            .init(.triggered, .linux, .v5_3),
            .init(.triggered, .macosXcodebuild, .v5_2),
            .init(.triggered, .ios, .v5_1)
        ])

        // MUT
        let res = sb.swiftVersionCompatibility()

        // validate
        XCTAssertEqual(res, .pending)
    }

    func test_swiftVersionCompatibility_partialPending() throws {
        // setup
        let sb = SignificantBuilds(builds: [
            .init(.ok, .linux, .v5_3),
            .init(.failed, .macosXcodebuild, .v5_2),
            .init(.triggered, .ios, .v5_1)
        ])

        // MUT
        let res = try XCTUnwrap(sb.swiftVersionCompatibility().values)

        // validate
        XCTAssertEqual(res.sorted(), [ .v5_3 ])
    }

    func test_platformCompatibility() throws {
        // setup
        let sb = SignificantBuilds(builds: [
            .init(.ok, .linux, .v5_3),
            .init(.ok, .macosXcodebuild, .v5_2),
            .init(.failed, .ios, .v5_1)
        ])
        
        // MUT
        let res = try XCTUnwrap(sb.platformCompatibility().values)

        // validate
        XCTAssertEqual(res.sorted(), [.macosXcodebuild, .linux])
    }

    func test_platformCompatibility_allPending() throws {
        // setup
        let sb = SignificantBuilds(builds: [
            .init(.triggered, .linux, .v5_3),
            .init(.triggered, .macosXcodebuild, .v5_2),
            .init(.triggered, .ios, .v5_1)
        ])

        // MUT
        let res = sb.platformCompatibility()

        // validate
        XCTAssertEqual(res, .pending)
    }

    func test_platformCompatibility_partialPending() throws {
        // setup
        let sb = SignificantBuilds(builds: [
            .init(.ok, .linux, .v5_3),
            .init(.failed, .macosXcodebuild, .v5_2),
            .init(.triggered, .ios, .v5_1)
        ])

        // MUT
        let res = try XCTUnwrap(sb.platformCompatibility().values)

        // validate
        XCTAssertEqual(res.sorted(), [ .linux ])
    }

    func test_query() throws {
        // setup
        let owner = "owner"
        let repo = "1"
        let p = try savePackage(on: app.db, "1")
        let v = try Version(package: p, latest: .release, reference: .tag(.init(1, 2, 3)))
        try v.save(on: app.db).wait()
        try Repository(package: p,
                       defaultBranch: "main",
                       license: .mit,
                       name: repo,
                       owner: owner).save(on: app.db).wait()
        // add builds
        try Build(version: v, platform: .linux, status: .ok, swiftVersion: .init(5, 3, 0))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .macosXcodebuild, status: .ok, swiftVersion: .init(5, 2, 2))
            .save(on: app.db)
            .wait()
        try p.$versions.load(on: app.db).wait()
        try p.versions.forEach {
            try $0.$builds.load(on: app.db).wait()
        }
        do { // save decoy
            let p = try savePackage(on: app.db, "2")
            try Version(package: p, latest: .release, reference: .tag(.init(1, 2, 3)))
                .save(on: app.db).wait()
            try Repository(package: p,
                           defaultBranch: "main",
                           license: .mit,
                           name: "2",
                           owner: owner).save(on: app.db).wait()
        }

        // MUT
        let db = try SignificantBuilds.query(on: app.db, owner: "owner", repository: "1").wait()

        // validate
        XCTFail("add validation")
    }

}
