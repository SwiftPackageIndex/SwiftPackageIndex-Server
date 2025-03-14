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

import Foundation

@testable import App

import Dependencies
import Fluent
import PostgresNIO
import SQLKit
import Testing
import Vapor


extension AllTests.BuildTests {

    @Test func save() async throws {
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "1")
            let v = try Version(package: pkg)
            try await v.save(on: app.db)
            let b = try Build(version: v,
                              buildCommand: #"xcrun xcodebuild -scheme "Foo""#,
                              jobUrl: "https://example.com/jobs/1",
                              logUrl: "https://example.com/logs/1",
                              platform: .linux,
                              status: .ok,
                              swiftVersion: .init(5, 2, 0))

            // MUT
            try await b.save(on: app.db)

            do {  // validate
                let b = try #require(try await Build.find(b.id, on: app.db))
                #expect(b.buildCommand == #"xcrun xcodebuild -scheme "Foo""#)
                #expect(b.jobUrl == "https://example.com/jobs/1")
                #expect(b.logUrl == "https://example.com/logs/1")
                #expect(b.platform == .linux)
                #expect(b.status == .ok)
                #expect(b.swiftVersion == .init(5, 2, 0))
                #expect(b.$version.id == v.id)
            }
        }
    }

    @Test func delete_cascade() async throws {
        // Ensure deleting a version also deletes the builds
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "1")
            let v = try Version(package: pkg)
            try await v.save(on: app.db)
            let b = try Build(version: v,
                              platform: .iOS,
                              status: .ok,
                              swiftVersion: .init(5, 2, 0))
            try await b.save(on: app.db)
            do {
                let count = try await Build.query(on: app.db).count()
                #expect(count == 1)
            }

            // MUT
            try await v.delete(on: app.db)

            // validate
            do {
                let count = try await Build.query(on: app.db).count()
                #expect(count == 0)
            }
        }
    }

    @Test func unique_constraint() async throws {
        // Ensure builds are unique over (id, platform, swiftVersion)
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "1")
            let v1 = try Version(package: pkg)
            try await v1.save(on: app.db)
            let v2 = try Version(package: pkg)
            try await v2.save(on: app.db)

            // MUT
            // initial save - ok
            try await Build(version: v1,
                            platform: .linux,
                            status: .ok,
                            swiftVersion: .init(5, 2, 0)).save(on: app.db)
            // different version - ok
            try await Build(version: v2,
                            platform: .linux,
                            status: .ok,
                            swiftVersion: .init(5, 2, 0)).save(on: app.db)
            // different platform - ok
            try await Build(version: v1,
                            platform: .macosXcodebuild,
                            status: .ok,
                            swiftVersion: .init(5, 2, 0)).save(on: app.db)
            // different swiftVersion - ok
            try await Build(version: v1,
                            platform: .linux,
                            status: .ok,
                            swiftVersion: .init(4, 0, 0)).save(on: app.db)

            // (v1, linx, 5.2.0) - not ok
            do {
                try await Build(version: v1,
                                platform: .linux,
                                status: .ok,
                                swiftVersion: .init(5, 2, 0)).save(on: app.db)
                Issue.record("Expected unique constraint violation")
            } catch let error as PSQLError {
                #expect(error.isUniqueViolation == true)
            } catch {
                Issue.record("unexpected error: \(error)")
            }

            // validate
            do {
                let count = try await Build.query(on: app.db).count()
                #expect(count == 4)
            }
        }
    }

    @Test func trigger() async throws {
        try await withApp { app in
            let buildId = UUID.id0
            let versionId = UUID.id1
            let called = QueueIsolated(false)
            try await withDependencies {
                $0.environment.awsDocsBucket = { "awsDocsBucket" }
                $0.environment.builderToken = { "builder token" }
                $0.environment.buildTimeout = { 10 }
                $0.environment.gitlabPipelineToken = { "pipeline token" }
                $0.environment.siteURL = { "http://example.com" }
                $0.buildSystem.triggerBuild = BuildSystemClient.liveValue.triggerBuild
                $0.httpClient.post = { @Sendable _, _, body in
                    called.setValue(true)
                    let body = try #require(body)
                    #expect(
                        try URLEncodedFormDecoder().decode(Gitlab.Builder.PostDTO.self, from: body)
                        == .init(token: "pipeline token",
                                 ref: "main",
                                 variables: [
                                    "API_BASEURL": "http://example.com/api",
                                    "AWS_DOCS_BUCKET": "awsDocsBucket",
                                    "BUILD_ID": buildId.uuidString,
                                    "BUILD_PLATFORM": "macos-xcodebuild",
                                    "BUILDER_TOKEN": "builder token",
                                    "CLONE_URL": "1",
                                    "REFERENCE": "main",
                                    "SWIFT_VERSION": "5.2",
                                    "TIMEOUT": "10m",
                                    "VERSION_ID": versionId.uuidString,
                                 ])
                    )
                    return try .created(jsonEncode: Gitlab.Builder.Response(webUrl: "http://web_url"))
                }
            } operation: {
                // setup
                let p = try await savePackage(on: app.db, "1")
                let v = try Version(id: versionId, package: p, reference: .branch("main"))
                try await v.save(on: app.db)

                // MUT
                let res = try await Build.trigger(database: app.db,
                                                  buildId: buildId,
                                                  isDocBuild: false,
                                                  platform: .macosXcodebuild,
                                                  swiftVersion: .init(5, 2, 4),
                                                  versionId: versionId)

                // validate
                #expect(called.value)
                #expect(res.status == .created)
            }
        }
    }

    @Test func trigger_isDocBuild() async throws {
        // Same test as test_trigger above, except we trigger with isDocBuild: true
        // and expect a 15m TIMEOUT instead of 10m
        let buildId = UUID.id0
        let versionId = UUID.id1
        let called = QueueIsolated(false)
        try await withDependencies {
            $0.environment.awsDocsBucket = { "awsDocsBucket" }
            $0.environment.builderToken = { "builder token" }
            $0.environment.buildTimeout = { 10 }
            $0.environment.gitlabPipelineToken = { "pipeline token" }
            $0.environment.siteURL = { "http://example.com" }
            $0.buildSystem.triggerBuild = BuildSystemClient.liveValue.triggerBuild
            $0.httpClient.post = { @Sendable _, _, body in
                called.setValue(true)
                let body = try #require(body)
                // only test the TIMEOUT value, the rest is already tested in `test_trigger` above
                let response = try? URLEncodedFormDecoder().decode(Gitlab.Builder.PostDTO.self, from: body)
                #expect(response != nil)
                #expect(response?.variables["TIMEOUT"] == "15m")
                return try .created(jsonEncode: Gitlab.Builder.Response(webUrl: "http://web_url"))
            }
        } operation: {
            try await withApp { app in
                // setup
                let p = try await savePackage(on: app.db, "1")
                let v = try Version(id: versionId, package: p, reference: .branch("main"))
                try await v.save(on: app.db)

                // MUT
                let res = try await Build.trigger(database: app.db,
                                                  buildId: buildId,
                                                  isDocBuild: true,
                                                  platform: .macosXcodebuild,
                                                  swiftVersion: .init(5, 2, 4),
                                                  versionId: versionId)

                // validate
                #expect(called.value)
                #expect(res.status == .created)
            }
        }
    }

    @Test func query() async throws {
        // Test querying by (platform/swiftVersion/versionId)
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "1")
            let v1 = try Version(package: pkg)
            try await v1.save(on: app.db)
            do { // decoy version and build
                let v2 = try Version(package: pkg)
                try await v2.save(on: app.db)
                try await Build(version: v2,
                                platform: .linux,
                                status: .ok,
                                swiftVersion: .init(5, 2, 0))
                .save(on: app.db)
            }
            let b1 = try Build(version: v1,
                               platform: .linux,
                               status: .ok,
                               swiftVersion: .init(5, 2, 0))
            try await b1.save(on: app.db)

            do {  // MUT - find via exactly matching Swift version
                let b = try await Build.query(on: app.db,
                                              platform: .linux,
                                              swiftVersion: .init(5, 2, 0),
                                              versionId: v1.requireID())
                #expect(b?.id == b1.id)
            }

            do {  // MUT - find via Swift version differing in patch revision
                let b = try await Build.query(on: app.db,
                                              platform: .linux,
                                              swiftVersion: .init(5, 2, 4),
                                              versionId: v1.requireID())
                #expect(b?.id == b1.id)
            }

            do {  // MUT - negative test: platform mismatch
                let b = try await Build.query(on: app.db,
                                              platform: .iOS,
                                              swiftVersion: .init(5, 2, 4),
                                              versionId: v1.requireID())
                #expect(b == nil)
            }

            do {  // MUT - negative test: Swift version mismatch
                let b = try await Build.query(on: app.db,
                                              platform: .linux,
                                              swiftVersion: .init(5, 5, 0),
                                              versionId: v1.requireID())
                #expect(b == nil)
            }

            do {  // MUT - negative test: versionId mismatch
                let b = try await Build.query(on: app.db,
                                              platform: .linux,
                                              swiftVersion: .init(5, 2, 4),
                                              versionId: UUID())
                #expect(b == nil)
            }
        }
    }

    @Test func delete_by_versionId() async throws {
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "1")
            let vid1 = UUID()
            let v1 = try Version(id: vid1, package: pkg)
            try await v1.save(on: app.db)
            let vid2 = UUID()
            let v2 = try Version(id: vid2, package: pkg)
            try await v2.save(on: app.db)
            try await Build(version: v1, platform: .iOS, status: .ok, swiftVersion: .v2)
                .save(on: app.db)
            try await Build(version: v2, platform: .iOS, status: .ok, swiftVersion: .v2)
                .save(on: app.db)

            // MUT
            let count = try await Build.delete(on: app.db, versionId: vid2)

            // validate
            #expect(count == 1)
            let builds = try await Build.query(on: app.db).all()
            #expect(builds.map(\.$version.id) == [vid1])
        }
    }

    @Test func delete_by_packageId() async throws {
        try await withApp { app in
            // setup
            let pkgId1 = UUID()
            let pkg1 = Package(id: pkgId1, url: "1")
            try await pkg1.save(on: app.db)
            let pkgId2 = UUID()
            let pkg2 = Package(id: pkgId2, url: "2")
            try await pkg2.save(on: app.db)

            let v1 = try Version(package: pkg1)
            try await v1.save(on: app.db)
            let v2 = try Version(package: pkg2)
            try await v2.save(on: app.db)

            // save different platforms as an easy way to check the correct one has been deleted
            try await Build(version: v1, platform: .iOS, status: .ok, swiftVersion: .v2)
                .save(on: app.db)
            try await Build(version: v2, platform: .linux, status: .ok, swiftVersion: .v2)
                .save(on: app.db)


            // MUT
            let count = try await Build.delete(on: app.db, packageId: pkgId2)

            // validate
            #expect(count == 1)
            let builds = try await Build.query(on: app.db).all()
            #expect(builds.map(\.platform) == [.iOS])
        }
    }

    @Test func delete_by_packageId_versionKind() async throws {
        try await withApp { app in
            // setup
            let pkgId1 = UUID()
            let pkg1 = Package(id: pkgId1, url: "1")
            try await pkg1.save(on: app.db)
            let pkgId2 = UUID()
            let pkg2 = Package(id: pkgId2, url: "2")
            try await pkg2.save(on: app.db)

            let v1 = try Version(package: pkg1)
            try await v1.save(on: app.db)
            let v2 = try Version(package: pkg2, latest: .defaultBranch)
            try await v2.save(on: app.db)
            let v3 = try Version(package: pkg2, latest: .release)
            try await v3.save(on: app.db)

            // save different platforms as an easy way to check the correct one has been deleted
            try await Build(version: v1, platform: .iOS, status: .ok, swiftVersion: .v2)
                .save(on: app.db)
            try await Build(version: v2, platform: .linux, status: .ok, swiftVersion: .v2)
                .save(on: app.db)
            try await Build(version: v3, platform: .tvOS, status: .ok, swiftVersion: .v2)
                .save(on: app.db)

            // MUT
            let count = try await Build.delete(on: app.db, packageId: pkgId2, versionKind: .defaultBranch)

            // validate
            #expect(count == 1)
            let builds = try await Build.query(on: app.db).all()
            #expect(builds.map(\.platform) == [.iOS, .tvOS])
        }
    }

    @Test func pending_to_triggered_migration() async throws {
        try await withApp { app in
            // setup
            let p = Package(url: "1")
            try await p.save(on: app.db)
            let v = try Version(package: p, latest: .defaultBranch)
            try await v.save(on: app.db)
            // save a Build with status 'triggered'
            try await Build(id: .id0, version: v, platform: .iOS, status: .triggered, swiftVersion: .v1).save(on: app.db)

            // MUT - test roll back to previous schema, migrating 'triggered' -> 'pending'
            try await UpdateBuildPendingToTriggered().revert(on: app.db)

            do {  // validate
                struct Row: Codable, Equatable {
                    var status: String
                }
                let result = try await (app.db as! SQLDatabase)
                    .raw("SELECT status FROM builds")
                    .all(decoding: Row.self)
                #expect(result == [.init(status: "pending")])
            }

            // MUT - test migrating 'pending' -> 'triggered'
            try await UpdateBuildPendingToTriggered().prepare(on: app.db)

            // validate
            let b = try #require(try await Build.find(.id0, on: app.db))
            #expect(b.status == .triggered)
        }
    }

    @Test func DeleteArmBuilds_migration() async throws {
        try await withApp { app in
            // setup
            let p = Package(url: "1")
            try await p.save(on: app.db)
            let v = try Version(package: p, latest: .defaultBranch)
            try await v.save(on: app.db)
            // save a Build with platform `macos-spm`
            try await Build(id: .id0, version: v, platform: .macosSpm, status: .triggered, swiftVersion: .v1).save(on: app.db)
            // save a Build with `macos-spm-arm` - we need to use raw SQL, because the platform enum
            // does not exist anymore
            try await (app.db as! SQLDatabase).raw(#"""
             INSERT INTO "builds" ("id", "version_id", "platform", "status", "swift_version") VALUES (\#(bind: UUID.id1), \#(bind: v.id), 'macos-spm-arm', 'ok', '{"major": 5, "minor": 6, "patch": 0}')
             """#).run()
            let count = try await Build.query(on: app.db).count()
            #expect(count == 2)


            // MUT
            try await DeleteArmBuilds().prepare(on: app.db)

            // validate
            let builds = try await Build.query(on: app.db).all()
            #expect(builds.count == 1)
            #expect(builds.first?.platform == .macosSpm)
        }
    }
    
}
