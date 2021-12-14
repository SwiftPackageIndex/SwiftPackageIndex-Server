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
            .init(.v5_5, .linux, .ok),
            .init(.v5_4, .macosSpm, .ok),
            .init(.v5_3, .ios, .failed)
        ])

        // MUT
        let res = try XCTUnwrap(sb.swiftVersionCompatibility().values)

        // validate
        XCTAssertEqual(res.sorted(), [.v5_4, .v5_5])
    }

    func test_swiftVersionCompatibility_allPending() throws {
        // setup
        let sb = SignificantBuilds(builds: [
            .init(.v5_5, .linux, .triggered),
            .init(.v5_4, .macosSpm, .triggered),
            .init(.v5_3, .ios, .triggered)
        ])

        // MUT
        let res = sb.swiftVersionCompatibility()

        // validate
        XCTAssertEqual(res, .pending)
    }

    func test_swiftVersionCompatibility_partialPending() throws {
        // setup
        let sb = SignificantBuilds(builds: [
            .init(.v5_5, .linux, .ok),
            .init(.v5_4, .macosSpm, .failed),
            .init(.v5_3, .ios, .triggered)
        ])

        // MUT
        let res = try XCTUnwrap(sb.swiftVersionCompatibility().values)

        // validate
        XCTAssertEqual(res.sorted(), [ .v5_5 ])
    }

    func test_platformCompatibility() throws {
        // setup
        let sb = SignificantBuilds(builds: [
            .init(.v5_5, .linux, .ok),
            .init(.v5_4, .macosSpm, .ok),
            .init(.v5_3, .ios, .failed)
        ])
        
        // MUT
        let res = try XCTUnwrap(sb.platformCompatibility().values)

        // validate
        XCTAssertEqual(res.sorted(), [.macosSpm, .linux])
    }

    func test_platformCompatibility_allPending() throws {
        // setup
        let sb = SignificantBuilds(builds: [
            .init(.v5_5, .linux, .triggered),
            .init(.v5_4, .macosSpm, .triggered),
            .init(.v5_3, .ios, .triggered)
        ])

        // MUT
        let res = sb.platformCompatibility()

        // validate
        XCTAssertEqual(res, .pending)
    }

    func test_platformCompatibility_partialPending() throws {
        // setup
        let sb = SignificantBuilds(builds: [
            .init(.v5_5, .linux, .ok),
            .init(.v5_4, .macosSpm, .failed),
            .init(.v5_3, .ios, .triggered)
        ])

        // MUT
        let res = try XCTUnwrap(sb.platformCompatibility().values)

        // validate
        XCTAssertEqual(res.sorted(), [ .linux ])
    }

    func test_query() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        let v = try Version(package: p, latest: .release, reference: .tag(.init(1, 2, 3)))
        try v.save(on: app.db).wait()
        try Repository(package: p,
                       defaultBranch: "main",
                       license: .mit,
                       name: "repo",
                       owner: "owner").save(on: app.db).wait()
        // add builds
        try Build(version: v, platform: .linux, status: .ok, swiftVersion: .v5_5)
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .macosSpm, status: .ok, swiftVersion: .v5_4)
            .save(on: app.db)
            .wait()
        try p.$versions.load(on: app.db).wait()
        try p.versions.forEach {
            try $0.$builds.load(on: app.db).wait()
        }
        do { // save decoy
            let p = try savePackage(on: app.db, "2")
            let v = try Version(package: p, latest: .release, reference: .tag(.init(2, 0, 0)))
            try v.save(on: app.db).wait()
            try Repository(package: p,
                           defaultBranch: "main",
                           license: .mit,
                           name: "decoy",
                           owner: "owner").save(on: app.db).wait()
            try Build(version: v, platform: .ios, status: .ok, swiftVersion: .v5_3)
                .save(on: app.db)
                .wait()
        }

        // MUT
        let sb: SignificantBuilds = try SignificantBuilds.query(on: app.db, owner: "owner", repository: "repo").wait()

        // validate
        XCTAssertEqual(sb.builds.sorted(), [
            .init(.v5_4, .macosSpm, .ok),
            .init(.v5_5, .linux, .ok)
        ])
    }

}


extension SignificantBuilds.BuildInfo: Comparable {
    public static func < (lhs: SignificantBuilds.BuildInfo, rhs: SignificantBuilds.BuildInfo) -> Bool {
        if lhs.swiftVersion != rhs.swiftVersion {
            return lhs.swiftVersion < rhs.swiftVersion
        }
        if lhs.platform != rhs.platform {
            return lhs.platform < rhs.platform
        }
        return lhs.status.rawValue < rhs.status.rawValue
    }
}
