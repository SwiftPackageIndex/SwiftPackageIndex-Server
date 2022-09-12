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

import SQLKit
import Vapor
import XCTest


class BuildTriggerTests: AppTestCase {

    func test_BuildTriggerInfo_emptyPair() throws {
        XCTAssertNotNil(BuildTriggerInfo(versionId: .id0, pairs: Set([BuildPair(.ios, .v5_5)])))
        XCTAssertNil(BuildTriggerInfo(versionId: .id0, pairs: []))
    }

    func test_fetchBuildCandidates_missingBuilds() throws {
        // setup
        let pkgIdComplete = UUID()
        let pkgIdIncomplete1 = UUID()
        let pkgIdIncomplete2 = UUID()
        do {  // save package with all builds
            let p = Package(id: pkgIdComplete, url: pkgIdComplete.uuidString.url)
            try p.save(on: app.db).wait()
            let v = try Version(package: p,
                                latest: .defaultBranch,
                                reference: .branch("main"))
            try v.save(on: app.db).wait()
            try BuildPair.all.forEach { pair in
                try Build(id: UUID(),
                          version: v,
                          platform: pair.platform,
                          status: .ok,
                          swiftVersion: pair.swiftVersion)
                    .save(on: app.db).wait()
            }
        }
        // save two packages with partially completed builds
        try [pkgIdIncomplete1, pkgIdIncomplete2].forEach { id in
            let p = Package(id: id, url: id.uuidString.url)
            try p.save(on: app.db).wait()
            try [Version.Kind.defaultBranch, .release].forEach { kind in
                let v = try Version(package: p,
                                    latest: kind,
                                    reference: kind == .release
                                        ? .tag(1, 2, 3)
                                        : .branch("main"))
                try v.save(on: app.db).wait()
                try BuildPair.all
                    .dropFirst() // skip one platform to create a build gap
                    .forEach { pair in
                        try Build(id: UUID(),
                                  version: v,
                                  platform: pair.platform,
                                  status: .ok,
                                  swiftVersion: pair.swiftVersion)
                            .save(on: app.db).wait()
                    }
            }
        }

        // MUT
        let ids = try fetchBuildCandidates(app.db).wait()

        // validate
        XCTAssertEqual(ids, [pkgIdIncomplete1, pkgIdIncomplete2])
    }

    func test_fetchBuildCandidates_noBuilds() throws {
        // Test finding build candidate without any builds (essentially
        // testing the `LEFT` in `LEFT JOIN builds`)
        // setup
        // save package without any builds
        let pkgId = UUID()
        let p = Package(id: pkgId, url: pkgId.uuidString.url)
        try p.save(on: app.db).wait()
        try [Version.Kind.defaultBranch, .release].forEach { kind in
            let v = try Version(package: p,
                                latest: kind,
                                reference: kind == .release
                                    ? .tag(1, 2, 3)
                                    : .branch("main"))
            try v.save(on: app.db).wait()
        }

        // MUT
        let ids = try fetchBuildCandidates(app.db).wait()

        // validate
        XCTAssertEqual(ids, [pkgId])
    }

    func test_missingPairs() throws {
         // Ensure we find missing builds purely via x.y Swift version,
         // i.e. ignoring patch version
         let allExceptFirst = Array(BuildPair.all.dropFirst())
         // just assert what the first one actually is so we test the right thing
         XCTAssertEqual(BuildPair.all.first, .init(.ios, .init(5, 4, 0)))
         // substitute in build with a different patch version
         let existing = allExceptFirst + [.init(.ios, .init(5, 4, 1))]

         // MUT & validate x.y.1 is matched as an existing x.y build
         XCTAssertEqual(missingPairs(existing: existing), Set())
     }

    func test_findMissingBuilds() throws {
        // setup
        let pkgId = UUID()
        let versionId = UUID()
        let droppedPlatform = try XCTUnwrap(Build.Platform.allActive.first)
        do {  // save package with partially completed builds
            let p = Package(id: pkgId, url: "1")
            try p.save(on: app.db).wait()
            let v = try Version(id: versionId,
                                package: p,
                                latest: .release,
                                reference: .tag(1, 2, 3))
            try v.save(on: app.db).wait()
            try Build.Platform.allActive
                .filter { $0 != droppedPlatform } // skip one platform to create a build gap
                .forEach { platform in
                try SwiftVersion.allActive.forEach { swiftVersion in
                    try Build(id: UUID(),
                              version: v,
                              platform: platform,
                              status: .ok,
                              swiftVersion: swiftVersion)
                        .save(on: app.db).wait()
                }
            }
        }

        // MUT
        let res = try findMissingBuilds(app.db, packageId: pkgId).wait()
        let expectedPairs = Set(SwiftVersion.allActive.map { BuildPair(droppedPlatform, $0) })
        XCTAssertEqual(res, [.init(versionId: versionId,
                                   pairs: expectedPairs,
                                   reference: .tag(1, 2, 3))!])
    }

    func test_triggerBuildsUnchecked() throws {
        // setup
        Current.builderToken = { "builder token" }
        Current.gitlabPipelineToken = { "pipeline token" }
        Current.siteURL = { "http://example.com" }

        // Use live dependency but replace actual client with a mock so we can
        // assert on the details being sent without actually making a request
        Current.triggerBuild = Gitlab.Builder.triggerBuild
        var queries = [Gitlab.Builder.PostDTO]()
        let client = MockClient { req, res in
            self.testQueue.sync {
                guard let query = try? req.query.decode(Gitlab.Builder.PostDTO.self) else { return }
                queries.append(query)
            }
            try? res.content.encode(
                Gitlab.Builder.Response.init(webUrl: "http://web_url")
            )
        }

        let versionId = UUID()
        do {  // save package with partially completed builds
            let p = Package(id: UUID(), url: "2")
            try p.save(on: app.db).wait()
            let v = try Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
            try v.save(on: app.db).wait()
        }
        let triggers = [BuildTriggerInfo(versionId: versionId,
                                         pairs: [BuildPair(.ios, .v5_4)])!]

        // MUT
        try triggerBuildsUnchecked(on: app.db,
                                   client: client,
                                   logger: app.logger,
                                   triggers: triggers).wait()

        // validate
        // ensure Gitlab requests go out
        XCTAssertEqual(queries.count, 1)
        XCTAssertEqual(queries.map { $0.variables["VERSION_ID"] }, [versionId.uuidString])
        XCTAssertEqual(queries.map { $0.variables["BUILD_PLATFORM"] }, ["ios"])
        XCTAssertEqual(queries.map { $0.variables["SWIFT_VERSION"] }, ["5.4"])

        // ensure the Build stubs is created to prevent re-selection
        let v = try Version.find(versionId, on: app.db).wait()
        try v?.$builds.load(on: app.db).wait()
        XCTAssertEqual(v?.builds.count, 1)
        XCTAssertEqual(v?.builds.map(\.status), [.triggered])
        XCTAssertEqual(v?.builds.map(\.jobUrl), ["http://web_url"])
    }

    func test_triggerBuildsUnchecked_supported() throws {
        // Explicitly test the full range of all currently triggered platforms and swift versions
        // setup
        Current.builderToken = { "builder token" }
        Current.gitlabPipelineToken = { "pipeline token" }
        Current.siteURL = { "http://example.com" }

        // Use live dependency but replace actual client with a mock so we can
        // assert on the details being sent without actually making a request
        Current.triggerBuild = Gitlab.Builder.triggerBuild
        var queries = [Gitlab.Builder.PostDTO]()
        let client = MockClient { req, res in
            self.testQueue.sync {
                guard let query = try? req.query.decode(Gitlab.Builder.PostDTO.self) else { return }
                queries.append(query)
            }
            try? res.content.encode(
                Gitlab.Builder.Response.init(webUrl: "http://web_url")
            )
        }

        let pkgId = UUID()
        let versionId = UUID()
        do {  // save package with partially completed builds
            let p = Package(id: pkgId, url: "2")
            try p.save(on: app.db).wait()
            let v = try Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
            try v.save(on: app.db).wait()
        }
        let triggers = try findMissingBuilds(app.db, packageId: pkgId).wait()

        // MUT
        try triggerBuildsUnchecked(on: app.db,
                                   client: client,
                                   logger: app.logger,
                                   triggers: triggers).wait()

        // validate
        // ensure Gitlab requests go out
        XCTAssertEqual(queries.count, 24)
        XCTAssertEqual(queries.map { $0.variables["VERSION_ID"] },
                       Array(repeating: versionId.uuidString, count: 24))
        let buildPlatforms = queries.compactMap { $0.variables["BUILD_PLATFORM"] }
        XCTAssertEqual(Dictionary(grouping: buildPlatforms, by: { $0 })
                        .mapValues(\.count),
                       ["ios": 4,
                        "macos-spm": 4,
                        "macos-xcodebuild": 4,
                        "linux": 4,
                        "watchos": 4,
                        "tvos": 4])
        let swiftVersions = queries.compactMap { $0.variables["SWIFT_VERSION"] }
        XCTAssertEqual(Dictionary(grouping: swiftVersions, by: { $0 })
                        .mapValues(\.count),
                       ["5.4": 6,
                        "5.5": 6,
                        "5.6": 6,
                        "5.7": 6])

        // ensure the Build stubs are created to prevent re-selection
        let v = try Version.find(versionId, on: app.db).wait()
        try v?.$builds.load(on: app.db).wait()
        XCTAssertEqual(v?.builds.count, 24)

        // ensure re-selection is empty
        XCTAssertEqual(try fetchBuildCandidates(app.db).wait(), [])
    }

    func test_triggerBuilds_checked() throws {
        // Ensure we respect the pipeline limit when triggering builds
        // setup
        Current.builderToken = { "builder token" }
        Current.gitlabPipelineToken = { "pipeline token" }
        Current.siteURL = { "http://example.com" }
        Current.gitlabPipelineLimit = { 300 }
        // Use live dependency but replace actual client with a mock so we can
        // assert on the details being sent without actually making a request
        Current.triggerBuild = Gitlab.Builder.triggerBuild
        var triggerCount = 0
        let client = MockClient { _, res in
            triggerCount += 1
            try? res.content.encode(
                Gitlab.Builder.Response.init(webUrl: "http://web_url")
            )
        }

        do {  // fist run: we are at capacity and should not be triggering more builds
            Current.getStatusCount = { _, _ in self.future(300) }

            let pkgId = UUID()
            let versionId = UUID()
            let p = Package(id: pkgId, url: "1")
            try p.save(on: app.db).wait()
            try Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
                .save(on: app.db).wait()

            // MUT
            try triggerBuilds(on: app.db,
                              client: client,
                              logger: app.logger,
                              mode: .packageId(pkgId, force: false)).wait()

            // validate
            XCTAssertEqual(triggerCount, 0)
            // ensure no build stubs have been created either
            let v = try Version.find(versionId, on: app.db).wait()
            try v?.$builds.load(on: app.db).wait()
            XCTAssertEqual(v?.builds.count, 0)
        }

        triggerCount = 0

        do {  // second run: we are just below capacity and allow more builds to be triggered
            Current.getStatusCount = { _, _ in self.future(299) }

            let pkgId = UUID()
            let versionId = UUID()
            let p = Package(id: pkgId, url: "2")
            try p.save(on: app.db).wait()
            try Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
                .save(on: app.db).wait()

            // MUT
            try triggerBuilds(on: app.db,
                              client: client,
                              logger: app.logger,
                              mode: .packageId(pkgId, force: false)).wait()

            // validate
            XCTAssertEqual(triggerCount, 24)
            // ensure builds are now in progress
            let v = try Version.find(versionId, on: app.db).wait()
            try v?.$builds.load(on: app.db).wait()
            XCTAssertEqual(v?.builds.count, 24)
        }

        do {  // third run: we are at capacity and using the `force` flag
            Current.getStatusCount = { _, _ in self.future(300) }

            var triggerCount = 0
            let client = MockClient { _, res in
                triggerCount += 1
                try? res.content.encode(
                    Gitlab.Builder.Response.init(webUrl: "http://web_url")
                )
            }

            let pkgId = UUID()
            let versionId = UUID()
            let p = Package(id: pkgId, url: "3")
            try p.save(on: app.db).wait()
            try Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
                .save(on: app.db).wait()

            // MUT
            try triggerBuilds(on: app.db,
                              client: client,
                              logger: app.logger,
                              mode: .packageId(pkgId, force: true)).wait()

            // validate
            XCTAssertEqual(triggerCount, 24)
            // ensure builds are now in progress
            let v = try Version.find(versionId, on: app.db).wait()
            try v?.$builds.load(on: app.db).wait()
            XCTAssertEqual(v?.builds.count, 24)
        }

    }

    func test_triggerBuilds_multiplePackages() throws {
        // Ensure we respect the pipeline limit when triggering builds for multiple package ids
        // setup
        Current.builderToken = { "builder token" }
        Current.gitlabPipelineToken = { "pipeline token" }
        Current.siteURL = { "http://example.com" }
        Current.gitlabPipelineLimit = { 300 }
        // Use live dependency but replace actual client with a mock so we can
        // assert on the details being sent without actually making a request
        Current.triggerBuild = Gitlab.Builder.triggerBuild
        var triggerCount = 0
        let client = MockClient { _, res in
            triggerCount += 1
            try? res.content.encode(
                Gitlab.Builder.Response.init(webUrl: "http://web_url")
            )
        }
        Current.getStatusCount = { _, _ in self.future(299 + triggerCount) }

        let pkgIds = [UUID(), UUID()]
        try pkgIds.forEach { id in
            let p = Package(id: id, url: id.uuidString.url)
            try p.save(on: app.db).wait()
            try Version(id: UUID(), package: p, latest: .defaultBranch, reference: .branch("main"))
                .save(on: app.db).wait()
        }

        // MUT
        try triggerBuilds(on: app.db,
                          client: client,
                          logger: app.logger,
                          mode: .limit(4)).wait()

        // validate - only the first batch must be allowed to trigger
        XCTAssertEqual(triggerCount, 24)
    }

    func test_triggerBuilds_trimming() throws {
        // Ensure we trim builds as part of triggering
        // setup
        Current.builderToken = { "builder token" }
        Current.gitlabPipelineToken = { "pipeline token" }
        Current.siteURL = { "http://example.com" }
        Current.gitlabPipelineLimit = { 300 }

        let client = MockClient { _, _ in }

        let pkgId = UUID()
        let versionId = UUID()
        let p = Package(id: pkgId, url: "2")
        try p.save(on: app.db).wait()
        let v = try Version(id: versionId, package: p, latest: nil, reference: .branch("main"))
        try v.save(on: app.db).wait()
        try Build(id: UUID(), version: v, platform: .ios, status: .triggered, swiftVersion: .v5_6)
            .save(on: app.db).wait()
        XCTAssertEqual(try Build.query(on: app.db).count().wait(), 1)

        // MUT
        try triggerBuilds(on: app.db,
                          client: client,
                          logger: app.logger,
                          mode: .packageId(pkgId, force: false)).wait()

        // validate
        XCTAssertEqual(try Build.query(on: app.db).count().wait(), 0)
    }

    func test_override_switch() throws {
        // Ensure don't trigger if the override is off
        // setup
        Current.builderToken = { "builder token" }
        Current.gitlabPipelineToken = { "pipeline token" }
        Current.siteURL = { "http://example.com" }
        // Use live dependency but replace actual client with a mock so we can
        // assert on the details being sent without actually making a request
        Current.triggerBuild = Gitlab.Builder.triggerBuild
        var triggerCount = 0
        let client = MockClient { _, res in
            triggerCount += 1
            try? res.content.encode(
                Gitlab.Builder.Response.init(webUrl: "http://web_url")
            )
        }

        do {  // confirm that the off switch prevents triggers
            Current.allowBuildTriggers = { false }


            let pkgId = UUID()
            let versionId = UUID()
            let p = Package(id: pkgId, url: "1")
            try p.save(on: app.db).wait()
            try Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
                .save(on: app.db).wait()

            // MUT
            try triggerBuilds(on: app.db,
                              client: client,
                              logger: app.logger,
                              mode: .packageId(pkgId, force: false)).wait()

            // validate
            XCTAssertEqual(triggerCount, 0)
        }

        triggerCount = 0

        do {  // flipping the switch to on should allow triggers to proceed
            Current.allowBuildTriggers = { true }

            let pkgId = UUID()
            let versionId = UUID()
            let p = Package(id: pkgId, url: "2")
            try p.save(on: app.db).wait()
            try Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
                .save(on: app.db).wait()

            // MUT
            try triggerBuilds(on: app.db,
                              client: client,
                              logger: app.logger,
                              mode: .packageId(pkgId, force: false)).wait()

            // validate
            XCTAssertEqual(triggerCount, 24)
        }
    }

    func test_downscaling() throws {
        // Test build trigger downscaling behaviour
        // setup
        Current.builderToken = { "builder token" }
        Current.gitlabPipelineToken = { "pipeline token" }
        Current.siteURL = { "http://example.com" }
        Current.buildTriggerDownscaling = { 0.05 }  // 5% downscaling rate
        // Use live dependency but replace actual client with a mock so we can
        // assert on the details being sent without actually making a request
        Current.triggerBuild = Gitlab.Builder.triggerBuild
        var triggerCount = 0
        let client = MockClient { _, res in
            triggerCount += 1
            try? res.content.encode(
                Gitlab.Builder.Response.init(webUrl: "http://web_url")
            )
        }

        do {  // confirm that bad luck prevents triggers
            Current.random = { _ in 0.05 }  // rolling a 0.05 ... so close!

            let pkgId = UUID()
            let versionId = UUID()
            let p = Package(id: pkgId, url: "1")
            try p.save(on: app.db).wait()
            try Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
                .save(on: app.db).wait()

            // MUT
            try triggerBuilds(on: app.db,
                              client: client,
                              logger: app.logger,
                              mode: .packageId(pkgId, force: false)).wait()

            // validate
            XCTAssertEqual(triggerCount, 0)
        }

        triggerCount = 0

        do {  // if we get lucky however...
            Current.random = { _ in 0.049 }  // rolling a 0.05 gets you in

            let pkgId = UUID()
            let versionId = UUID()
            let p = Package(id: pkgId, url: "2")
            try p.save(on: app.db).wait()
            try Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
                .save(on: app.db).wait()

            // MUT
            try triggerBuilds(on: app.db,
                              client: client,
                              logger: app.logger,
                              mode: .packageId(pkgId, force: false)).wait()

            // validate
            XCTAssertEqual(triggerCount, 24)
        }

    }

    func test_trimBuilds() throws {
        // setup
        let pkgId = UUID()
        let p = Package(id: pkgId, url: "1")
        try p.save(on: app.db).wait()
        // v1 is a significant version, only old triggered builds should be deleted
        let v1 = try Version(package: p, latest: .defaultBranch)
        try v1.save(on: app.db).wait()
        // v2 is not a significant version - all its builds should be deleted
        let v2 = try Version(package: p)
        try v2.save(on: app.db).wait()

        let deleteId1 = UUID()
        let keepBuildId1 = UUID()
        let keepBuildId2 = UUID()

        do {  // v1 builds
            // old triggered build (delete)
            try Build(id: deleteId1,
                      version: v1, platform: .ios, status: .triggered, swiftVersion: .v5_5)
                .save(on: app.db).wait()
            // new triggered build (keep)
            try Build(id: keepBuildId1,
                      version: v1, platform: .ios, status: .triggered, swiftVersion: .v5_6)
                .save(on: app.db).wait()
            // old non-triggered build (keep)
            try Build(id: keepBuildId2,
                      version: v1, platform: .ios, status: .ok, swiftVersion: .v5_4)
                .save(on: app.db).wait()

            // make old builds "old" by resetting "created_at"
            try [deleteId1, keepBuildId2].forEach { id in
                let sql = "update builds set created_at = created_at - interval '5 hours' where id = '\(id.uuidString)'"
                try (app.db as! SQLDatabase).raw(.init(sql)).run().wait()
            }
        }

        do {  // v2 builds (should all be deleted)
            // old triggered build
            try Build(id: UUID(),
                      version: v2, platform: .ios, status: .triggered, swiftVersion: .v5_5)
                .save(on: app.db).wait()
            // new triggered build
            try Build(id: UUID(),
                      version: v2, platform: .ios, status: .triggered, swiftVersion: .v5_6)
                .save(on: app.db).wait()
            // old non-triggered build
            try Build(id: UUID(),
                      version: v2, platform: .ios, status: .ok, swiftVersion: .v5_4)
                .save(on: app.db).wait()
        }

        XCTAssertEqual(try Build.query(on: app.db).count().wait(), 6)

        // MUT
        let deleteCount = try trimBuilds(on: app.db).wait()

        // validate
        XCTAssertEqual(deleteCount, 4)
        XCTAssertEqual(try Build.query(on: app.db).count().wait(), 2)
        XCTAssertEqual(try Build.query(on: app.db).all().wait().map(\.id),
                       [keepBuildId1, keepBuildId2])
    }

    func test_trimBuilds_bindParam() throws {
        // Bind parameter issue regression test, details:
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/909
        // setup
        let pkgId = UUID()
        let p = Package(id: pkgId, url: "1")
        try p.save(on: app.db).wait()
        let v1 = try Version(package: p, latest: .defaultBranch)
        try v1.save(on: app.db).wait()
        try Build(version: v1, platform: .ios, status: .triggered, swiftVersion: .v5_6)
            .save(on: app.db).wait()

        let db = try XCTUnwrap(app.db as? SQLDatabase)
        try db.raw("update builds set created_at = NOW() - interval '1 h'")
            .run().wait()

        // MUT
        let deleteCount = try trimBuilds(on: app.db).wait()

        // validate
        XCTAssertEqual(deleteCount, 0)
    }

    func test_trimBuilds_timeout() throws {
        // Ensure timouts are not deleted
        // setup
        let pkgId = UUID()
        let p = Package(id: pkgId, url: "1")
        try p.save(on: app.db).wait()
        let v = try Version(package: p, latest: .defaultBranch)
        try v.save(on: app.db).wait()

        let buildId = UUID()
        try Build(id: buildId,
                  version: v,
                  platform: .ios,
                  status: .timeout,
                  swiftVersion: .v5_4)
            .save(on: app.db).wait()

        // MUT
        var deleteCount = try trimBuilds(on: app.db).wait()

        // validate
        XCTAssertEqual(deleteCount, 0)
        XCTAssertEqual(try Build.query(on: app.db).count().wait(), 1)

        do { // make build "old" by resetting "created_at"
            let sql = "update builds set created_at = created_at - interval '4 hours' where id = '\(buildId.uuidString)'"
            try (app.db as! SQLDatabase).raw(.init(sql)).run().wait()
        }

        // MUT
        deleteCount = try trimBuilds(on: app.db).wait()

        // validate
        XCTAssertEqual(deleteCount, 0)
        XCTAssertEqual(try Build.query(on: app.db).count().wait(), 1)
    }

    func test_trimBuilds_infrastructureError() throws {
        // Ensure infrastructerErrors are deleted
        // setup
        let pkgId = UUID()
        let p = Package(id: pkgId, url: "1")
        try p.save(on: app.db).wait()
        let v = try Version(package: p, latest: .defaultBranch)
        try v.save(on: app.db).wait()

        let buildId = UUID()
        try Build(id: buildId,
                  version: v,
                  platform: .ios,
                  status: .infrastructureError,
                  swiftVersion: .v5_4)
            .save(on: app.db).wait()

        // MUT
        var deleteCount = try trimBuilds(on: app.db).wait()

        // validate
        XCTAssertEqual(deleteCount, 0)
        XCTAssertEqual(try Build.query(on: app.db).count().wait(), 1)

        do { // make build "old" by resetting "created_at"
            let sql = "update builds set created_at = created_at - interval '5 hours' where id = '\(buildId.uuidString)'"
            try (app.db as! SQLDatabase).raw(.init(sql)).run().wait()
        }

        // MUT
        deleteCount = try trimBuilds(on: app.db).wait()

        // validate
        XCTAssertEqual(deleteCount, 1)
        XCTAssertEqual(try Build.query(on: app.db).count().wait(), 0)
    }

    func test_BuildPair_Equatable() throws {
        XCTAssertEqual(BuildPair(.ios, .init(5, 3, 0)),
                       BuildPair(.ios, .init(5, 3, 3)))
        XCTAssertFalse(BuildPair(.ios, .init(5, 3, 0))
                       == BuildPair(.ios, .init(5, 4, 0)))
        XCTAssertFalse(BuildPair(.ios, .init(5, 3, 0))
                       == BuildPair(.tvos, .init(5, 3, 0)))
    }

    func test_BuildPair_Hashable() throws {
        let set = Set([BuildPair(.ios, .init(5, 3, 0))])
        XCTAssertTrue(set.contains(BuildPair(.ios, .init(5, 3, 3))))
        XCTAssertFalse(set.contains(BuildPair(.ios, .init(5, 4, 0))))
        XCTAssertFalse(set.contains(BuildPair(.macosSpm, .init(5, 3, 0))))
    }

    func test_issue_1065() throws {
        // Regression test for
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1065
        // addressing a problem with findMissingBuilds not ignoring
        // Swift patch versions.
        // setup
        let pkgId = UUID()
        let versionId = UUID()
        do {  // save package with a different Swift patch version
              // (5.7.1 when SwiftVersion.v5_7 is "5.7.0")
            let p = Package(id: pkgId, url: "1")
            try p.save(on: app.db).wait()
            let v = try Version(id: versionId,
                                package: p,
                                latest: .release,
                                reference: .tag(1, 2, 3))
            try v.save(on: app.db).wait()
            try Build(id: UUID(),
                      version: v,
                      platform: .ios,
                      status: .ok,
                      swiftVersion: .init(5, 7, 1))
                .save(on: app.db).wait()
        }

        // MUT
        let res = try findMissingBuilds(app.db, packageId: pkgId).wait()
        XCTAssertEqual(res.count, 1)
        let triggerInfo = try XCTUnwrap(res.first)
        XCTAssertEqual(triggerInfo.pairs.count, 23)
        XCTAssertTrue(!triggerInfo.pairs.contains(.init(.ios, .v5_7)))
    }

    func test_BuildPair_droppingLatestSwiftVersion() throws {
        XCTAssertEqual(
            Set([
                BuildPair(.ios, .v5_6),
                BuildPair(.ios, .v5_7),
            ]).droppingLatestSwiftVersion(),
            Set([.init(.ios, .v5_6)])
        )
        XCTAssertEqual(
            Set([
                BuildPair(.ios, .v5_5),
                BuildPair(.ios, .v5_6),
            ]).droppingLatestSwiftVersion(),
            Set([
                BuildPair(.ios, .v5_5),
                BuildPair(.ios, .v5_6),
            ])
        )
    }

    func test_BuildTriggerInfo_droppingLatestSwiftVersion() throws {
        let pairs = Set([
            BuildPair(.ios, .v5_6),
            BuildPair(.ios, .v5_7),
        ])
        let trigger = BuildTriggerInfo(versionId: .id0, pairs: pairs)

        XCTAssertEqual(trigger?.droppingLatestSwiftVersion().pairs,
                       Set([BuildPair(.ios, .v5_6)]))
    }

    func test_triggerBuilds_buildTriggerLatestSwiftVersionDownscaling() throws {
        // Test build trigger downscaling behaviour of latest Swift version builds
        // setup
        Current.builderToken = { "builder token" }
        Current.gitlabPipelineToken = { "pipeline token" }
        Current.siteURL = { "http://example.com" }
        Current.buildTriggerLatestSwiftVersionDownscaling = { true }
        // Use live dependency but replace actual client with a mock so we can
        // assert on the details being sent without actually making a request
        Current.triggerBuild = Gitlab.Builder.triggerBuild
        var triggerCount = 0
        let client = MockClient { _, res in
            triggerCount += 1
            try? res.content.encode(
                Gitlab.Builder.Response.init(webUrl: "http://web_url")
            )
        }


        do {  // if the queue is < 50% full, all builds are triggered
            triggerCount = 0
            Current.gitlabPipelineLimit = { 100 }
            Current.getStatusCount = { _, status in
                switch status {
                    case .pending:
                        return self.future(49)

                    default:
                        return self.future(0)
                }
            }

            let pkgId = UUID()
            let versionId = UUID()
            let p = Package(id: pkgId, url: "1")
            try p.save(on: app.db).wait()
            try Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
                .save(on: app.db).wait()

            // MUT
            try triggerBuilds(on: app.db,
                              client: client,
                              logger: app.logger,
                              mode: .packageId(pkgId, force: false)).wait()

            // validate
            XCTAssertEqual(triggerCount, 24) // all builds are triggered
        }


        do {  // if the queue is >= 50% full, 5.7 builds are skipped
            triggerCount = 0
            Current.gitlabPipelineLimit = { 100 }
            Current.getStatusCount = { _, status in
                switch status {
                    case .pending:
                        return self.future(50)

                    default:
                        return self.future(0)
                }
            }

            let pkgId = UUID()
            let versionId = UUID()
            let p = Package(id: pkgId, url: "2")
            try p.save(on: app.db).wait()
            try Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
                .save(on: app.db).wait()

            // MUT
            try triggerBuilds(on: app.db,
                              client: client,
                              logger: app.logger,
                              mode: .packageId(pkgId, force: false)).wait()

            // validate
            XCTAssertEqual(triggerCount, 18) // 24 - 6 builds for 5.7
        }

    }

}
