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

import Fluent
import PostgresNIO
import SQLKit
import XCTVapor


class BuildTests: AppTestCase {
    
    func test_save() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        let v = try Version(package: pkg)
        try v.save(on: app.db).wait()
        let b = try Build(version: v,
                          buildCommand: #"xcrun xcodebuild -scheme "Foo""#,
                          jobUrl: "https://example.com/jobs/1",
                          logUrl: "https://example.com/logs/1",
                          platform: .linux,
                          status: .ok,
                          swiftVersion: .init(5, 2, 0))
        
        // MUT
        try b.save(on: app.db).wait()
        
        do {  // validate
            let b = try XCTUnwrap(Build.find(b.id, on: app.db).wait())
            XCTAssertEqual(b.buildCommand, #"xcrun xcodebuild -scheme "Foo""#)
            XCTAssertEqual(b.jobUrl, "https://example.com/jobs/1")
            XCTAssertEqual(b.logUrl, "https://example.com/logs/1")
            XCTAssertEqual(b.platform, .linux)
            XCTAssertEqual(b.status, .ok)
            XCTAssertEqual(b.swiftVersion, .init(5, 2, 0))
            XCTAssertEqual(b.$version.id, v.id)
        }
    }
    
    func test_delete_cascade() throws {
        // Ensure deleting a version also deletes the builds
        // setup
        let pkg = try savePackage(on: app.db, "1")
        let v = try Version(package: pkg)
        try v.save(on: app.db).wait()
        let b = try Build(version: v,
                          platform: .ios,
                          status: .ok,
                          swiftVersion: .init(5, 2, 0))
        try b.save(on: app.db).wait()
        XCTAssertEqual(try Build.query(on: app.db).count().wait(), 1)
        
        // MUT
        try v.delete(on: app.db).wait()
        
        // validate
        XCTAssertEqual(try Build.query(on: app.db).count().wait(), 0)
    }
    
    func test_unique_constraint() throws {
        // Ensure builds are unique over (id, platform, swiftVersion)
        // setup
        let pkg = try savePackage(on: app.db, "1")
        let v1 = try Version(package: pkg)
        try v1.save(on: app.db).wait()
        let v2 = try Version(package: pkg)
        try v2.save(on: app.db).wait()
        
        // MUT
        // initial save - ok
        try Build(version: v1,
                  platform: .linux,
                  status: .ok,
                  swiftVersion: .init(5, 2, 0)).save(on: app.db).wait()
        // different version - ok
        try Build(version: v2,
                  platform: .linux,
                  status: .ok,
                  swiftVersion: .init(5, 2, 0)).save(on: app.db).wait()
        // different platform - ok
        try Build(version: v1,
                  platform: .macosXcodebuild,
                  status: .ok,
                  swiftVersion: .init(5, 2, 0)).save(on: app.db).wait()
        // different swiftVersion - ok
        try Build(version: v1,
                  platform: .linux,
                  status: .ok,
                  swiftVersion: .init(4, 0, 0)).save(on: app.db).wait()
        
        // (v1, linx, 5.2.0) - not ok
        XCTAssertThrowsError(
            try Build(version: v1,
                      platform: .linux,
                      status: .ok,
                      swiftVersion: .init(5, 2, 0)).save(on: app.db).wait()
        ) {
            XCTAssertEqual(($0 as? PostgresError)?.code, .uniqueViolation)
        }
        
        // validate
        XCTAssertEqual(try Build.query(on: app.db).count().wait(), 4)
    }
    
    func test_trigger() throws {
        Current.builderToken = { "builder token" }
        Current.gitlabPipelineToken = { "pipeline token" }
        Current.siteURL = { "http://example.com" }
        // setup
        let p = try savePackage(on: app.db, "1")
        let v = try Version(package: p, reference: .branch("main"))
        try v.save(on: app.db).wait()
        let versionID = try XCTUnwrap(v.id)

        // Use live dependency but replace actual client with a mock so we can
        // assert on the details being sent without actually making a request
        Current.triggerBuild = Gitlab.Builder.triggerBuild
        var called = false
        let client = MockClient { req, res in
            called = true
            res.status = .created
            // validate request data
            XCTAssertEqual(try? req.query.decode(Gitlab.Builder.PostDTO.self),
                           Gitlab.Builder.PostDTO(
                            token: "pipeline token",
                            ref: "main",
                            variables: [
                                "API_BASEURL": "http://example.com/api",
                                "BUILD_PLATFORM": "macos-xcodebuild",
                                "BUILDER_TOKEN": "builder token",
                                "CLONE_URL": "1",
                                "REFERENCE": "main",
                                "SWIFT_VERSION": "5.2",
                                "VERSION_ID": versionID.uuidString,
                            ]))
        }
        
        // MUT
        let res = try Build.trigger(database: app.db,
                                    client: client,
                                    platform: .macosXcodebuild,
                                    swiftVersion: .init(5, 2, 4),
                                    versionId: versionID).wait()
        
        // validate
        XCTAssertTrue(called)
        XCTAssertEqual(res, .created)
    }
    
    func test_upsert() throws {
        // Test "upsert" (insert or update)
        // setup
        let pkg = try savePackage(on: app.db, "1")
        let v = try Version(package: pkg)
        try v.save(on: app.db).wait()
        
        // MUT
        // initial save - ok
        try Build(version: v,
                  platform: .linux,
                  status: .ok,
                  swiftVersion: .init(5, 2, 0))
            .upsert(on: app.db).wait()
        
        // validate
        do {
            XCTAssertEqual(try Build.query(on: app.db).count().wait(), 1)
            let b = try XCTUnwrap(try Build.query(on: app.db).first().wait())
            XCTAssertEqual(b.platform, .linux)
            XCTAssertEqual(b.status, .ok)
            XCTAssertEqual(b.swiftVersion, .init(5, 2, 0))
        }

        // MUT
        // next insert is update
        try Build(version: v,
                  platform: .linux,
                  status: .failed,
                  swiftVersion: .init(5, 2, 0))
            .upsert(on: app.db).wait()
        
        // validate
        do {
            XCTAssertEqual(try Build.query(on: app.db).count().wait(), 1)
            let b = try XCTUnwrap(try Build.query(on: app.db).first().wait())
            XCTAssertEqual(b.platform, .linux)
            XCTAssertEqual(b.status, .failed)
            XCTAssertEqual(b.swiftVersion, .init(5, 2, 0))
        }

        // MUT
        // insert with different patch version updates as well
        try Build(version: v,
                  platform: .linux,
                  status: .failed,
                  swiftVersion: .init(5, 2, 4))
            .upsert(on: app.db).wait()

        // validate
        do {
            XCTAssertEqual(try Build.query(on: app.db).count().wait(), 1)
            let b = try XCTUnwrap(try Build.query(on: app.db).first().wait())
            XCTAssertEqual(b.platform, .linux)
            XCTAssertEqual(b.status, .failed)
            XCTAssertEqual(b.swiftVersion, .init(5, 2, 4))
        }
    }

    func test_noneSucceeded() throws {
        let pkg = Package(id: UUID(), url: "1")
        let v = try Version(id: UUID(), package: pkg)
        let p = Build.Platform.ios
        let sv = SwiftVersion.init(5, 2, 0)
        func mkBuild(_ status: Build.Status) -> Build {
            return try! Build(version: v, platform: p, status: status, swiftVersion: sv)
        }
        XCTAssertTrue([mkBuild(.failed), mkBuild(.failed)].noneSucceeded)
        XCTAssertFalse([mkBuild(.ok), mkBuild(.failed)].noneSucceeded)
    }

    func test_anySucceeded() throws {
        let pkg = Package(id: UUID(), url: "1")
        let v = try Version(id: UUID(), package: pkg)
        let p = Build.Platform.ios
        let sv = SwiftVersion.init(5, 2, 0)
        func mkBuild(_ status: Build.Status) -> Build {
            return try! Build(version: v, platform: p, status: status, swiftVersion: sv)
        }
        XCTAssertTrue([mkBuild(.ok), mkBuild(.failed)].anySucceeded)
        XCTAssertFalse([mkBuild(.failed), mkBuild(.failed)].anySucceeded)
    }

    func test_nonePending() throws {
        // setup
        let pkg = Package(id: UUID(), url: "1")
        let v = try Version(id: UUID(), package: pkg)
        let p = Build.Platform.ios
        let sv = SwiftVersion.init(5, 2, 0)
        func mkBuild(_ status: Build.Status) -> Build {
            return try! Build(version: v, platform: p, status: status, swiftVersion: sv)
        }
        // MUT & verification
        XCTAssertTrue([mkBuild(.ok), mkBuild(.failed)].nonePending)
        XCTAssertFalse([mkBuild(.ok), mkBuild(.triggered)].nonePending)
        // timeouts will not be retried - therefore they are not pending
        XCTAssertTrue([mkBuild(.ok), mkBuild(.timeout)].nonePending)
        // infrastructure errors _will_ be retried - they are pending
        XCTAssertFalse([mkBuild(.ok), mkBuild(.infrastructureError)].nonePending)
    }

    func test_anyPending() throws {
        // setup
        let pkg = Package(id: UUID(), url: "1")
        let v = try Version(id: UUID(), package: pkg)
        let p = Build.Platform.ios
        let sv = SwiftVersion.init(5, 2, 0)
        func mkBuild(_ status: Build.Status) -> Build {
            return try! Build(version: v, platform: p, status: status, swiftVersion: sv)
        }
        // MUT & verification
        XCTAssertFalse([mkBuild(.ok), mkBuild(.failed)].anyPending)
        XCTAssertTrue([mkBuild(.ok), mkBuild(.triggered)].anyPending)
        // timeouts will not be retried - therefore they are not pending
        XCTAssertTrue([mkBuild(.ok), mkBuild(.timeout)].nonePending)
        // infrastructure errors _will_ be retried - they are pending
        XCTAssertFalse([mkBuild(.ok), mkBuild(.infrastructureError)].nonePending)
    }

    func test_buildStatus() throws {
        // Test build status aggregation, in particular see
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/666
        // setup
        let pkg = Package(id: UUID(), url: "1")
        let v = try Version(id: UUID(), package: pkg)
        let p = Build.Platform.ios
        let sv = SwiftVersion.init(5, 2, 0)
        func mkBuild(_ status: Build.Status) -> Build {
            return try! Build(version: v, platform: p, status: status, swiftVersion: sv)
        }
        // MUT & verification
        XCTAssertEqual([mkBuild(.ok), mkBuild(.failed)].buildStatus, .compatible)
        XCTAssertEqual([mkBuild(.triggered), mkBuild(.triggered)].buildStatus, .unknown)
        XCTAssertEqual([mkBuild(.failed), mkBuild(.triggered)].buildStatus, .unknown)
        XCTAssertEqual([mkBuild(.ok), mkBuild(.triggered)].buildStatus, .compatible)
    }

    func test_delete_by_versionId() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        let vid1 = UUID()
        let v1 = try Version(id: vid1, package: pkg)
        try v1.save(on: app.db).wait()
        let vid2 = UUID()
        let v2 = try Version(id: vid2, package: pkg)
        try v2.save(on: app.db).wait()
        try Build(version: v1, platform: .ios, status: .ok, swiftVersion: .v5_2)
            .save(on: app.db).wait()
        try Build(version: v2, platform: .ios, status: .ok, swiftVersion: .v5_2)
            .save(on: app.db).wait()

        // MUT
        let count = try Build.delete(on: app.db, versionId: vid2).wait()

        // validate
        XCTAssertEqual(count, 1)
        let builds = try Build.query(on: app.db).all().wait()
        XCTAssertEqual(builds.map(\.$version.id), [vid1])
    }

    func test_delete_by_packageId() throws {
        // setup
        let pkgId1 = UUID()
        let pkg1 = Package(id: pkgId1, url: "1")
        try pkg1.save(on: app.db).wait()
        let pkgId2 = UUID()
        let pkg2 = Package(id: pkgId2, url: "2")
        try pkg2.save(on: app.db).wait()

        let v1 = try Version(package: pkg1)
        try v1.save(on: app.db).wait()
        let v2 = try Version(package: pkg2)
        try v2.save(on: app.db).wait()

        // save different platforms as an easy way to check the correct one has been deleted
        try Build(version: v1, platform: .ios, status: .ok, swiftVersion: .v5_2)
            .save(on: app.db).wait()
        try Build(version: v2, platform: .linux, status: .ok, swiftVersion: .v5_2)
            .save(on: app.db).wait()


        // MUT
        let count = try Build.delete(on: app.db, packageId: pkgId2).wait()

        // validate
        XCTAssertEqual(count, 1)
        let builds = try Build.query(on: app.db).all().wait()
        XCTAssertEqual(builds.map(\.platform), [.ios])
    }

    func test_delete_by_packageId_versionKind() throws {
        // setup
        let pkgId1 = UUID()
        let pkg1 = Package(id: pkgId1, url: "1")
        try pkg1.save(on: app.db).wait()
        let pkgId2 = UUID()
        let pkg2 = Package(id: pkgId2, url: "2")
        try pkg2.save(on: app.db).wait()

        let v1 = try Version(package: pkg1)
        try v1.save(on: app.db).wait()
        let v2 = try Version(package: pkg2, latest: .defaultBranch)
        try v2.save(on: app.db).wait()
        let v3 = try Version(package: pkg2, latest: .release)
        try v3.save(on: app.db).wait()

        // save different platforms as an easy way to check the correct one has been deleted
        try Build(version: v1, platform: .ios, status: .ok, swiftVersion: .v5_2)
            .save(on: app.db).wait()
        try Build(version: v2, platform: .linux, status: .ok, swiftVersion: .v5_2)
            .save(on: app.db).wait()
        try Build(version: v3, platform: .tvos, status: .ok, swiftVersion: .v5_2)
            .save(on: app.db).wait()

        // MUT
        let count = try Build.delete(on: app.db, packageId: pkgId2, versionKind: .defaultBranch).wait()

        // validate
        XCTAssertEqual(count, 1)
        let builds = try Build.query(on: app.db).all().wait()
        XCTAssertEqual(builds.map(\.platform), [.ios, .tvos])
    }

    func test_pending_to_triggered_migration() throws {
        // setup
        let p = Package(url: "1")
        try p.save(on: app.db).wait()
        let v = try Version(package: p, latest: .defaultBranch)
        try v.save(on: app.db).wait()
        // save a Build with status 'triggered'
        try Build(id: .id0, version: v, platform: .ios, status: .triggered, swiftVersion: .v5_5).save(on: app.db).wait()

        // MUT - test roll back to previous schema, migrating 'triggered' -> 'pending'
        try UpdateBuildPendingToTriggered().revert(on: app.db).wait()

        do {  // validate
            struct Row: Codable, Equatable {
                var status: String
            }
            let result = try (app.db as! SQLDatabase)
                .raw("SELECT status FROM builds")
                .all(decoding: Row.self)
                .wait()
            XCTAssertEqual(result, [.init(status: "pending")])
        }

        // MUT - test migrating 'pending' -> 'triggered'
        try UpdateBuildPendingToTriggered().prepare(on: app.db).wait()

        // validate
        let b = try XCTUnwrap(Build.find(.id0, on: app.db).wait())
        XCTAssertEqual(b.status, .triggered)
    }

}
