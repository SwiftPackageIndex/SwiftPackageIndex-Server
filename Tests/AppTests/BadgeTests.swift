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


class BadgeTests: AppTestCase {
    typealias PackageResult = PackageController.PackageResult

    func test_swiftVersionCompatibility() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p, name: "bar", owner: "foo").save(on: app.db).wait()
        let v = try Version(package: p, reference: .tag(.init(1, 2, 3)))
        try v.save(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: p.id!).wait()
        // update versions
        try updateLatestVersions(on: app.db, package: jpr).wait()
        // add builds
        try Build(version: v, platform: .linux, status: .ok, swiftVersion: .init(5, 3, 0))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .macosXcodebuild, status: .ok, swiftVersion: .init(5, 2, 2))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .ios, status: .failed, swiftVersion: .init(5, 0, 2))
            .save(on: app.db)
            .wait()
        let pr = try PackageResult.query(on: app.db, owner: "foo", repository: "bar").wait()
        let builds = SignificantBuilds(versions: pr.versions)

        // MUT
        let res = try XCTUnwrap(Badge.swiftVersionCompatibility(builds).values)

        // validate
        XCTAssertEqual(res.sorted(), [.v5_2, .v5_3])
    }

    func test_swiftVersionCompatibility_allPending() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p, name: "bar", owner: "foo").save(on: app.db).wait()
        let v = try Version(package: p, reference: .tag(.init(1, 2, 3)))
        try v.save(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: p.id!).wait()
        // update versions
        try updateLatestVersions(on: app.db, package: jpr).wait()
        // add builds
        try Build(version: v, platform: .linux, status: .triggered, swiftVersion: .init(5, 3, 0))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .macosXcodebuild, status: .triggered, swiftVersion: .init(5, 2, 2))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .ios, status: .triggered, swiftVersion: .init(5, 0, 2))
            .save(on: app.db)
            .wait()
        let pr = try PackageResult.query(on: app.db, owner: "foo", repository: "bar").wait()
        let builds = SignificantBuilds(versions: pr.versions)

        // MUT
        let res = Badge.swiftVersionCompatibility(builds)

        // validate
        XCTAssertEqual(res, .pending)
    }

    func test_swiftVersionCompatibility_partialPending() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p, name: "bar", owner: "foo").save(on: app.db).wait()
        let v = try Version(package: p, reference: .tag(.init(1, 2, 3)))
        try v.save(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: p.id!).wait()
        // update versions
        try updateLatestVersions(on: app.db, package: jpr).wait()
        // add builds
        try Build(version: v, platform: .linux, status: .ok, swiftVersion: .init(5, 3, 0))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .macosXcodebuild, status: .failed, swiftVersion: .init(5, 2, 2))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .ios, status: .triggered, swiftVersion: .init(5, 0, 2))
            .save(on: app.db)
            .wait()
        let pr = try PackageResult.query(on: app.db, owner: "foo", repository: "bar").wait()
        let builds = SignificantBuilds(versions: pr.versions)

        // MUT
        let res = try XCTUnwrap(Badge.swiftVersionCompatibility(builds).values)

        // validate
        XCTAssertEqual(res.sorted(), [ .v5_3 ])
    }

    func test_platformCompatibility() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p, name: "bar", owner: "foo").save(on: app.db).wait()
        let v = try Version(package: p, reference: .tag(.init(1, 2, 3)))
        try v.save(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: p.id!).wait()
        // update versions
        try updateLatestVersions(on: app.db, package: jpr).wait()
        // add builds
        try Build(version: v, platform: .linux, status: .ok, swiftVersion: .init(5, 3, 0))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .macosXcodebuild, status: .ok, swiftVersion: .init(5, 2, 2))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .ios, status: .failed, swiftVersion: .init(5, 0, 2))
            .save(on: app.db)
            .wait()
        let pr = try PackageResult.query(on: app.db, owner: "foo", repository: "bar").wait()
        let builds = SignificantBuilds(versions: pr.versions)

        // MUT
        let res = try XCTUnwrap(Badge.platformCompatibility(builds).values)

        // validate
        XCTAssertEqual(res.sorted(), [.macosXcodebuild, .linux])
    }

    func test_platformCompatibility_allPending() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p, name: "bar", owner: "foo").save(on: app.db).wait()
        let v = try Version(package: p, reference: .tag(.init(1, 2, 3)))
        try v.save(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: p.id!).wait()
        // update versions
        try updateLatestVersions(on: app.db, package: jpr).wait()
        // add builds
        try Build(version: v, platform: .linux, status: .triggered, swiftVersion: .init(5, 3, 0))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .macosXcodebuild, status: .triggered, swiftVersion: .init(5, 2, 2))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .ios, status: .triggered, swiftVersion: .init(5, 0, 2))
            .save(on: app.db)
            .wait()
        let pr = try PackageResult.query(on: app.db, owner: "foo", repository: "bar").wait()
        let builds = SignificantBuilds(versions: pr.versions)

        // MUT
        let res = Badge.platformCompatibility(builds)

        // validate
        XCTAssertEqual(res, .pending)
    }

    func test_platformCompatibility_partialPending() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p, name: "bar", owner: "foo").save(on: app.db).wait()
        let v = try Version(package: p, reference: .tag(.init(1, 2, 3)))
        try v.save(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: p.id!).wait()
        // update versions
        try updateLatestVersions(on: app.db, package: jpr).wait()
        // add builds
        try Build(version: v, platform: .linux, status: .ok, swiftVersion: .init(5, 3, 0))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .macosXcodebuild, status: .failed, swiftVersion: .init(5, 2, 2))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .ios, status: .triggered, swiftVersion: .init(5, 0, 2))
            .save(on: app.db)
            .wait()
        let pr = try PackageResult.query(on: app.db, owner: "foo", repository: "bar").wait()
        let builds = SignificantBuilds(versions: pr.versions)

        // MUT
        let res = try XCTUnwrap(Badge.platformCompatibility(builds).values)

        // validate
        XCTAssertEqual(res.sorted(), [ .linux ])
    }

    func test_badgeMessage_swiftVersions() throws {
        XCTAssertEqual(Badge.badgeMessage(swiftVersions: [.v5_2, .v5_1, .v5_4]), "5.4 | 5.2 | 5.1")
        XCTAssertNil(Badge.badgeMessage(swiftVersions: []))
    }

    func test_badgeMessage_platforms() throws {
        XCTAssertEqual(Badge.badgeMessage(platforms: [.linux, .ios, .macosXcodebuild, .macosSpm]),
                       "iOS | macOS | Linux")
        XCTAssertNil(Badge.badgeMessage(platforms: []))
    }

}
