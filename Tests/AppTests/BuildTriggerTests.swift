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

import SQLKit
import Vapor
import XCTest


class BuildTriggerTests: AppTestCase {

    func test_BuildTriggerInfo_emptyPair() throws {
        XCTAssertNotNil(BuildTriggerInfo(versionId: .id0, pairs: Set([BuildPair(.iOS, .v1)])))
        XCTAssertNil(BuildTriggerInfo(versionId: .id0, pairs: []))
    }

    func test_fetchBuildCandidates_missingBuilds() async throws {
        // setup
        let pkgIdComplete = UUID()
        let pkgIdIncomplete1 = UUID()
        let pkgIdIncomplete2 = UUID()
        do {  // save package with all builds
            let p = Package(id: pkgIdComplete, url: pkgIdComplete.uuidString.url)
            try await p.save(on: app.db)
            let v = try Version(package: p,
                                latest: .defaultBranch,
                                reference: .branch("main"))
            try await v.save(on: app.db)
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
        let ids = try await fetchBuildCandidates(app.db)

        // validate
        XCTAssertEqual(ids, [pkgIdIncomplete1, pkgIdIncomplete2])
    }

    func test_fetchBuildCandidates_noBuilds() async throws {
        // Test finding build candidate without any builds (essentially
        // testing the `LEFT` in `LEFT JOIN builds`)
        // setup
        // save package without any builds
        let pkgId = UUID()
        let p = Package(id: pkgId, url: pkgId.uuidString.url)
        try await p.save(on: app.db)
        try [Version.Kind.defaultBranch, .release].forEach { kind in
            let v = try Version(package: p,
                                latest: kind,
                                reference: kind == .release
                                    ? .tag(1, 2, 3)
                                    : .branch("main"))
            try v.save(on: app.db).wait()
        }

        // MUT
        let ids = try await fetchBuildCandidates(app.db)

        // validate
        XCTAssertEqual(ids, [pkgId])
    }

    func test_fetchBuildCandidates_exceptLatestSwiftVersion() async throws {
        // setup
        do {  // save package with just latest Swift version builds missing
            let p = Package(id: .id1, url: "1")
            try await p.save(on: app.db)
            let v = try Version(id: .init(),
                                package: p,
                                latest: .release,
                                reference: .tag(1, 2, 3))
            try await v.save(on: app.db)
            for platform in Build.Platform.allActive {
                for swiftVersion in SwiftVersion
                    .allActive
                    // skip latest Swift version build
                    .filter({ $0 != .latest }) {
                    try await Build(id: .init(),
                                        version: v,
                                        platform: platform,
                                        status: .ok,
                                        swiftVersion: swiftVersion)
                        .save(on: app.db)
                }
            }
        }
        do {  // save package without any builds
            let p = Package(id: .id2, url: "2")
            try await p.save(on: app.db)
            let v = try Version(id: .id3,
                                package: p,
                                latest: .release,
                                reference: .tag(1, 2, 3))
            try await v.save(on: app.db)
        }

        // MUT
        let ids = try await fetchBuildCandidates(app.db, withLatestSwiftVersion: false)

        // validate
        // Only package with missing non-latest Swift version builds (.id2) must be selected
        XCTAssertEqual(ids, [.id2])
    }

    func test_fetchBuildCandidates_priorityIDs() async throws {
        // Ensure allow-listed IDs can be prioritised. See
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2159
        // for details
        // setup
        let pkgIdIncomplete1 = UUID()
        let pkgIdIncomplete2 = UUID()
        Current.buildTriggerAllowList = { [pkgIdIncomplete2] }
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
        let ids = try await fetchBuildCandidates(app.db)

        // validate
        XCTAssertEqual(ids, [pkgIdIncomplete2, pkgIdIncomplete1])
    }

    func test_missingPairs() throws {
         // Ensure we find missing builds purely via x.y Swift version,
         // i.e. ignoring patch version
         let allExceptFirst = Array(BuildPair.all.dropFirst())
         // just assert what the first one actually is so we test the right thing
         XCTAssertEqual(BuildPair.all.first, .init(.iOS, .v1))
         // substitute in build with a different patch version
        let existing = allExceptFirst + [.init(.iOS, .v1.incrementingPatchVersion())]

         // MUT & validate x.y.1 is matched as an existing x.y build
         XCTAssertEqual(missingPairs(existing: existing), Set())
     }

    func test_findMissingBuilds() async throws {
        // setup
        let pkgId = UUID()
        let versionId = UUID()
        let droppedPlatform = try XCTUnwrap(Build.Platform.allActive.first)
        do {  // save package with partially completed builds
            let p = Package(id: pkgId, url: "1")
            try await p.save(on: app.db)
            let v = try Version(id: versionId,
                                package: p,
                                latest: .release,
                                reference: .tag(1, 2, 3))
            try await v.save(on: app.db)
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
        let res = try await findMissingBuilds(app.db, packageId: pkgId)
        let expectedPairs = Set(SwiftVersion.allActive.map { BuildPair(droppedPlatform, $0) })
        XCTAssertEqual(res, [.init(versionId: versionId,
                                   pairs: expectedPairs,
                                   reference: .tag(1, 2, 3))!])
    }

    func test_triggerBuildsUnchecked() async throws {
        // setup
        Current.builderToken = { "builder token" }
        Current.gitlabPipelineToken = { "pipeline token" }
        Current.siteURL = { "http://example.com" }

        // Use live dependency but replace actual client with a mock so we can
        // assert on the details being sent without actually making a request
        Current.triggerBuild = Gitlab.Builder.triggerBuild
        let queries = QueueIsolated<[Gitlab.Builder.PostDTO]>([])
        let client = MockClient { req, res in
            guard let query = try? req.query.decode(Gitlab.Builder.PostDTO.self) else { return }
            queries.withValue { $0.append(query) }
            try? res.content.encode(
                Gitlab.Builder.Response.init(webUrl: "http://web_url")
            )
        }

        let versionId = UUID()
        do {  // save package with partially completed builds
            let p = Package(id: UUID(), url: "2")
            try await p.save(on: app.db)
            let v = try Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
            try await v.save(on: app.db)
        }
        let triggers = [BuildTriggerInfo(versionId: versionId,
                                         pairs: [BuildPair(.iOS, .v1)])!]

        // MUT
        try await triggerBuildsUnchecked(on: app.db,
                                         client: client,
                                         logger: app.logger,
                                         triggers: triggers)

        // validate
        // ensure Gitlab requests go out
        XCTAssertEqual(queries.count, 1)
        XCTAssertEqual(queries.value.map { $0.variables["VERSION_ID"] }, [versionId.uuidString])
        XCTAssertEqual(queries.value.map { $0.variables["BUILD_PLATFORM"] }, ["ios"])
        XCTAssertEqual(queries.value.map { $0.variables["SWIFT_VERSION"] }, ["5.6"])

        // ensure the Build stubs is created to prevent re-selection
        let v = try await Version.find(versionId, on: app.db)
        try await v?.$builds.load(on: app.db)
        XCTAssertEqual(v?.builds.count, 1)
        XCTAssertEqual(v?.builds.map(\.status), [.triggered])
        XCTAssertEqual(v?.builds.map(\.jobUrl), ["http://web_url"])
    }

    func test_triggerBuildsUnchecked_supported() async throws {
        // Explicitly test the full range of all currently triggered platforms and swift versions
        // setup
        Current.builderToken = { "builder token" }
        Current.gitlabPipelineToken = { "pipeline token" }
        Current.siteURL = { "http://example.com" }

        // Use live dependency but replace actual client with a mock so we can
        // assert on the details being sent without actually making a request
        Current.triggerBuild = Gitlab.Builder.triggerBuild
        let queries = QueueIsolated<[Gitlab.Builder.PostDTO]>([])
        let client = MockClient { req, res in
            guard let query = try? req.query.decode(Gitlab.Builder.PostDTO.self) else { return }
            queries.withValue { $0.append(query) }
            try? res.content.encode(
                Gitlab.Builder.Response.init(webUrl: "http://web_url")
            )
        }

        let pkgId = UUID()
        let versionId = UUID()
        do {  // save package with partially completed builds
            let p = Package(id: pkgId, url: "2")
            try await p.save(on: app.db)
            let v = try Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
            try await v.save(on: app.db)
        }
        let triggers = try await findMissingBuilds(app.db, packageId: pkgId)

        // MUT
        try await triggerBuildsUnchecked(on: app.db,
                                         client: client,
                                         logger: app.logger,
                                         triggers: triggers)

        // validate
        // ensure Gitlab requests go out
        XCTAssertEqual(queries.count, 24)
        XCTAssertEqual(queries.value.map { $0.variables["VERSION_ID"] },
                       Array(repeating: versionId.uuidString, count: 24))
        let buildPlatforms = queries.value.compactMap { $0.variables["BUILD_PLATFORM"] }
        XCTAssertEqual(Dictionary(grouping: buildPlatforms, by: { $0 })
                        .mapValues(\.count),
                       ["ios": 4,
                        "macos-spm": 4,
                        "macos-xcodebuild": 4,
                        "linux": 4,
                        "watchos": 4,
                        "tvos": 4])
        let swiftVersions = queries.value.compactMap { $0.variables["SWIFT_VERSION"] }
        XCTAssertEqual(Dictionary(grouping: swiftVersions, by: { $0 })
                        .mapValues(\.count),
                       ["\(SwiftVersion.v1)": 6,
                        "\(SwiftVersion.v2)": 6,
                        "\(SwiftVersion.v3)": 6,
                        "\(SwiftVersion.v4)": 6])

        // ensure the Build stubs are created to prevent re-selection
        let v = try await Version.find(versionId, on: app.db)
        try await v?.$builds.load(on: app.db)
        XCTAssertEqual(v?.builds.count, 24)

        // ensure re-selection is empty
        let candidates = try await fetchBuildCandidates(app.db)
        XCTAssertEqual(candidates, [])
    }

    func test_triggerBuildsUnchecked_build_exists() async throws {
        // Tests error handling when a build record already exists and `create` raises a
        // uq:builds.version_id+builds.platform+builds.swift_version+v2
        // unique key violation.
        // The only way this can currently happen is by running a manual trigger command
        // from a container in the dev or prod envs (docker exec ...), like so:
        //   ./Run trigger-builds -v {version-id} -p macos-spm -s 5.7
        // This is how we routinely manually trigger doc-related builds.
        // This test ensures that the build record is updated in this case rather than
        // being completely ignored because the command errors out.
        // See https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2237
        // setup
        Current.builderToken = { "builder token" }
        Current.gitlabPipelineToken = { "pipeline token" }
        Current.siteURL = { "http://example.com" }

        // Use live dependency but replace actual client with a mock so we can
        // assert on the details being sent without actually making a request
        Current.triggerBuild = Gitlab.Builder.triggerBuild
        let queries = QueueIsolated<[Gitlab.Builder.PostDTO]>([])
        let client = MockClient { req, res in
            guard let query = try? req.query.decode(Gitlab.Builder.PostDTO.self) else { return }
            queries.withValue { $0.append(query) }
            try? res.content.encode(
                Gitlab.Builder.Response.init(webUrl: "http://web_url")
            )
        }

        let buildId = UUID()
        let versionId = UUID()
        do {  // save package with a build that we re-trigger
            let p = Package(id: UUID(), url: "2")
            try await p.save(on: app.db)
            let v = try Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
            try await v.save(on: app.db)
            try await Build(id: buildId,
                            version: v,
                            platform: .macosSpm,
                            status: .failed,
                            swiftVersion: .v3).save(on: app.db)

        }
        let triggers = [BuildTriggerInfo(versionId: versionId,
                                         pairs: [BuildPair(.macosSpm, .v3)])!]

        // MUT
        try await triggerBuildsUnchecked(on: app.db,
                                         client: client,
                                         logger: app.logger,
                                         triggers: triggers)

        // validate
        // triggerBuildsUnchecked always creates a new buildId,
        // so the triggered id must be different from the existing one
        let newBuildId = try XCTUnwrap(queries.value.first?.variables["BUILD_ID"]
            .flatMap(UUID.init(uuidString:)))
        XCTAssertNotEqual(newBuildId, buildId)

        // ensure existing build record is updated
        let v = try await Version.find(versionId, on: app.db)
        try await v?.$builds.load(on: app.db)
        XCTAssertEqual(v?.builds.count, 1)
        XCTAssertEqual(v?.builds.map(\.id), [newBuildId])
        XCTAssertEqual(v?.builds.map(\.status), [.triggered])
        XCTAssertEqual(v?.builds.map(\.jobUrl), ["http://web_url"])
    }

    func test_triggerBuilds_checked() async throws {
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
            try await p.save(on: app.db)
            try await Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
                .save(on: app.db)

            // MUT
            try await triggerBuilds(on: app.db,
                                    client: client,
                                    logger: app.logger,
                                    mode: .packageId(pkgId, force: false))

            // validate
            XCTAssertEqual(triggerCount, 0)
            // ensure no build stubs have been created either
            let v = try await Version.find(versionId, on: app.db)
            try await v?.$builds.load(on: app.db)
            XCTAssertEqual(v?.builds.count, 0)
        }

        triggerCount = 0

        do {  // second run: we are just below capacity and allow more builds to be triggered
            Current.getStatusCount = { _, _ in self.future(299) }

            let pkgId = UUID()
            let versionId = UUID()
            let p = Package(id: pkgId, url: "2")
            try await p.save(on: app.db)
            try await Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
                .save(on: app.db)

            // MUT
            try await triggerBuilds(on: app.db,
                                    client: client,
                                    logger: app.logger,
                                    mode: .packageId(pkgId, force: false))

            // validate
            XCTAssertEqual(triggerCount, 24)
            // ensure builds are now in progress
            let v = try await Version.find(versionId, on: app.db)
            try await v?.$builds.load(on: app.db)
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
            try await p.save(on: app.db)
            try await Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
                .save(on: app.db)

            // MUT
            try await triggerBuilds(on: app.db,
                                    client: client,
                                    logger: app.logger,
                                    mode: .packageId(pkgId, force: true))

            // validate
            XCTAssertEqual(triggerCount, 24)
            // ensure builds are now in progress
            let v = try await Version.find(versionId, on: app.db)
            try await v?.$builds.load(on: app.db)
            XCTAssertEqual(v?.builds.count, 24)
        }

    }

    func test_triggerBuilds_multiplePackages() async throws {
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
        try await triggerBuilds(on: app.db,
                                client: client,
                                logger: app.logger,
                                mode: .limit(4))

        // validate - only the first batch must be allowed to trigger
        XCTAssertEqual(triggerCount, 24)
    }

    func test_triggerBuilds_trimming() async throws {
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
        try await p.save(on: app.db)
        let v = try Version(id: versionId, package: p, latest: nil, reference: .branch("main"))
        try await v.save(on: app.db)
        try await Build(id: UUID(), version: v, platform: .iOS, status: .triggered, swiftVersion: .v2)
            .save(on: app.db)
        XCTAssertEqual(try Build.query(on: app.db).count().wait(), 1)

        // MUT
        try await triggerBuilds(on: app.db,
                                client: client,
                                logger: app.logger,
                                mode: .packageId(pkgId, force: false))

        // validate
        let count = try await Build.query(on: app.db).count()
        XCTAssertEqual(count, 0)
    }

    func test_triggerBuilds_error() async throws {
        // Ensure we trim builds as part of triggering
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
            // let the 5th trigger succeed to ensure we don't early out on errors
            if triggerCount == 5 {
                try? res.content.encode(
                    Gitlab.Builder.Response.init(webUrl: "http://web_url")
                )
            } else {
                struct Response: Content {
                    var message: String
                }
                try? res.content.encode(Response(message: "Too many pipelines created in the last minute. Try again later."))
                res.status = .tooManyRequests
            }
            triggerCount += 1
        }

        let logger = Logger(label: "noop") { _ in SwiftLogNoOpLogHandler() }

        let p = Package(id: .id0, url: "1")
        try await p.save(on: app.db)
        let v = try Version(id: .id1, package: p, latest: .defaultBranch, reference: .branch("main"))
        try await v.save(on: app.db)

        // MUT
        try await triggerBuilds(on: app.db,
                                client: client,
                                logger: logger,
                                mode: .packageId(.id0, force: false))

        // validate that one build record is saved, for the successful trigger
        let count = try await Build.query(on: app.db).count()
        XCTAssertEqual(count, 1)
    }

    func test_buildTriggerCandidatesSkipLatestSwiftVersion() throws {
        do {
            // Test downscaling set to 10%
            Current.buildTriggerLatestSwiftVersionDownscaling = { 0.1 }

            // Roll just below threshold should keep latest Swift version
            Current.random = { _ in 0.09}
            XCTAssertEqual(Current.buildTriggerCandidatesWithLatestSwiftVersion, true)
            // Roll on threshold should skip latest Swift version
            Current.random = { _ in 0.1}
            XCTAssertEqual(Current.buildTriggerCandidatesWithLatestSwiftVersion, false)
            // Roll just above threshold should skip latest Swift version
            Current.random = { _ in 0.11}
            XCTAssertEqual(Current.buildTriggerCandidatesWithLatestSwiftVersion, false)
        }

        do {
            // Set downscaling to 0 in order to fully skip latest Swift version based candidate selection
            Current.buildTriggerLatestSwiftVersionDownscaling = { 0 }

            Current.random = { _ in 0 }
            XCTAssertEqual(Current.buildTriggerCandidatesWithLatestSwiftVersion, false)
            Current.random = { _ in 0.5 }
            XCTAssertEqual(Current.buildTriggerCandidatesWithLatestSwiftVersion, false)
            Current.random = { _ in 1 }
            XCTAssertEqual(Current.buildTriggerCandidatesWithLatestSwiftVersion, false)
        }

        do {
            // Set downscaling to 1 in order to fully disable any downscaling
            Current.buildTriggerLatestSwiftVersionDownscaling = { 1 }

            Current.random = { _ in 0 }
            XCTAssertEqual(Current.buildTriggerCandidatesWithLatestSwiftVersion, true)
            Current.random = { _ in 0.5 }
            XCTAssertEqual(Current.buildTriggerCandidatesWithLatestSwiftVersion, true)
            Current.random = { _ in 1 }
            XCTAssertEqual(Current.buildTriggerCandidatesWithLatestSwiftVersion, true)
        }
    }

    func test_override_switch() async throws {
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
            try await p.save(on: app.db)
            try await Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
                .save(on: app.db)

            // MUT
            try await triggerBuilds(on: app.db,
                                    client: client,
                                    logger: app.logger,
                                    mode: .packageId(pkgId, force: false))

            // validate
            XCTAssertEqual(triggerCount, 0)
        }

        triggerCount = 0

        do {  // flipping the switch to on should allow triggers to proceed
            Current.allowBuildTriggers = { true }

            let pkgId = UUID()
            let versionId = UUID()
            let p = Package(id: pkgId, url: "2")
            try await p.save(on: app.db)
            try await Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
                .save(on: app.db)

            // MUT
            try await triggerBuilds(on: app.db,
                                    client: client,
                                    logger: app.logger,
                                    mode: .packageId(pkgId, force: false))

            // validate
            XCTAssertEqual(triggerCount, 24)
        }
    }

    func test_downscaling() async throws {
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
            try await p.save(on: app.db)
            try await Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
                .save(on: app.db)

            // MUT
            try await triggerBuilds(on: app.db,
                                    client: client,
                                    logger: app.logger,
                                    mode: .packageId(pkgId, force: false))

            // validate
            XCTAssertEqual(triggerCount, 0)
        }

        triggerCount = 0

        do {  // if we get lucky however...
            Current.random = { _ in 0.049 }  // rolling a 0.049 gets you in

            let pkgId = UUID()
            let versionId = UUID()
            let p = Package(id: pkgId, url: "2")
            try await p.save(on: app.db)
            try await Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
                .save(on: app.db)

            // MUT
            try await triggerBuilds(on: app.db,
                                    client: client,
                                    logger: app.logger,
                                    mode: .packageId(pkgId, force: false))

            // validate
            XCTAssertEqual(triggerCount, 24)
        }

    }

    func test_downscaling_allow_list_override() async throws {
        // Test build trigger downscaling behaviour for allow-listed packages
        // setup
        Current.builderToken = { "builder token" }
        Current.gitlabPipelineToken = { "pipeline token" }
        Current.siteURL = { "http://example.com" }
        Current.buildTriggerDownscaling = { 0.05 }  // 5% downscaling rate
        let pkgId = UUID()
        Current.buildTriggerAllowList = { [pkgId] }
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

        do {  // confirm that we trigger even when rolling above the threshold
            Current.random = { _ in 0.051 }

            let versionId = UUID()
            let p = Package(id: pkgId, url: "https://github.com/foo/bar.git")
            try await p.save(on: app.db)
            try await Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
                .save(on: app.db)

            // MUT
            try await triggerBuilds(on: app.db,
                                    client: client,
                                    logger: app.logger,
                                    mode: .packageId(pkgId, force: false))

            // validate
            XCTAssertEqual(triggerCount, 24)
        }
    }

    func test_trimBuilds() async throws {
        // setup
        let pkgId = UUID()
        let p = Package(id: pkgId, url: "1")
        try await p.save(on: app.db)
        // v1 is a significant version, only old triggered builds should be deleted
        let v1 = try Version(package: p, latest: .defaultBranch)
        try await v1.save(on: app.db)
        // v2 is not a significant version - all its builds should be deleted
        let v2 = try Version(package: p)
        try await v2.save(on: app.db)

        let deleteId1 = UUID()
        let keepBuildId1 = UUID()
        let keepBuildId2 = UUID()

        do {  // v1 builds
            // old triggered build (delete)
            try await Build(id: deleteId1,
                      version: v1, platform: .iOS, status: .triggered, swiftVersion: .v2)
                .save(on: app.db)
            // new triggered build (keep)
            try await Build(id: keepBuildId1,
                      version: v1, platform: .iOS, status: .triggered, swiftVersion: .v3)
                .save(on: app.db)
            // old non-triggered build (keep)
            try await Build(id: keepBuildId2,
                      version: v1, platform: .iOS, status: .ok, swiftVersion: .v1)
                .save(on: app.db)

            // make old builds "old" by resetting "created_at"
            try [deleteId1, keepBuildId2].forEach { id in
                let sql = "update builds set created_at = created_at - interval '5 hours' where id = '\(id.uuidString)'"
                try (app.db as! SQLDatabase).raw(.init(sql)).run().wait()
            }
        }

        do {  // v2 builds (should all be deleted)
            // old triggered build
            try await Build(id: UUID(),
                      version: v2, platform: .iOS, status: .triggered, swiftVersion: .v2)
                .save(on: app.db)
            // new triggered build
            try await Build(id: UUID(),
                      version: v2, platform: .iOS, status: .triggered, swiftVersion: .v3)
                .save(on: app.db)
            // old non-triggered build
            try await Build(id: UUID(),
                      version: v2, platform: .iOS, status: .ok, swiftVersion: .v1)
                .save(on: app.db)
        }

        XCTAssertEqual(try Build.query(on: app.db).count().wait(), 6)

        // MUT
        let deleteCount = try await trimBuilds(on: app.db)

        // validate
        XCTAssertEqual(deleteCount, 4)
        let buildCount = try await Build.query(on: app.db).count()
        XCTAssertEqual(buildCount, 2)
        let buildIds = try await Build.query(on: app.db).all().map(\.id)
        XCTAssertEqual(buildIds, [keepBuildId1, keepBuildId2])
    }

    func test_trimBuilds_bindParam() async throws {
        // Bind parameter issue regression test, details:
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/909
        // setup
        let pkgId = UUID()
        let p = Package(id: pkgId, url: "1")
        try await p.save(on: app.db)
        let v1 = try Version(package: p, latest: .defaultBranch)
        try await v1.save(on: app.db)
        try await Build(version: v1, platform: .iOS, status: .triggered, swiftVersion: .v2)
            .save(on: app.db)

        let db = try XCTUnwrap(app.db as? SQLDatabase)
        try await db.raw("update builds set created_at = NOW() - interval '1 h'")
            .run()

        // MUT
        let deleteCount = try await trimBuilds(on: app.db)

        // validate
        XCTAssertEqual(deleteCount, 0)
    }

    func test_trimBuilds_timeout() async throws {
        // Ensure timouts are not deleted
        // setup
        let pkgId = UUID()
        let p = Package(id: pkgId, url: "1")
        try await p.save(on: app.db)
        let v = try Version(package: p, latest: .defaultBranch)
        try await v.save(on: app.db)

        let buildId = UUID()
        try await Build(id: buildId,
                        version: v,
                        platform: .iOS,
                        status: .timeout,
                        swiftVersion: .v1).save(on: app.db)

        // MUT
        var deleteCount = try await trimBuilds(on: app.db)

        // validate
        XCTAssertEqual(deleteCount, 0)
        XCTAssertEqual(try Build.query(on: app.db).count().wait(), 1)

        do { // make build "old" by resetting "created_at"
            let sql = "update builds set created_at = created_at - interval '4 hours' where id = '\(buildId.uuidString)'"
            try await (app.db as! SQLDatabase).raw(.init(sql)).run()
        }

        // MUT
        deleteCount = try await trimBuilds(on: app.db)

        // validate
        XCTAssertEqual(deleteCount, 0)
        let buildCount = try await Build.query(on: app.db).count()
        XCTAssertEqual(buildCount, 1)
    }

    func test_trimBuilds_infrastructureError() async throws {
        // Ensure infrastructerErrors are deleted
        // setup
        let pkgId = UUID()
        let p = Package(id: pkgId, url: "1")
        try await p.save(on: app.db)
        let v = try Version(package: p, latest: .defaultBranch)
        try await v.save(on: app.db)

        let buildId = UUID()
        try await Build(id: buildId,
                        version: v,
                        platform: .iOS,
                        status: .infrastructureError,
                        swiftVersion: .v1).save(on: app.db)

        // MUT
        var deleteCount = try await trimBuilds(on: app.db)

        // validate
        XCTAssertEqual(deleteCount, 0)
        XCTAssertEqual(try Build.query(on: app.db).count().wait(), 1)

        do { // make build "old" by resetting "created_at"
            let sql = "update builds set created_at = created_at - interval '5 hours' where id = '\(buildId.uuidString)'"
            try await (app.db as! SQLDatabase).raw(.init(sql)).run()
        }

        // MUT
        deleteCount = try await trimBuilds(on: app.db)

        // validate
        XCTAssertEqual(deleteCount, 1)
        let buildCount = try await Build.query(on: app.db).count()
        XCTAssertEqual(buildCount, 0)
    }

    func test_BuildPair_counts() throws {
        // Sanity checks for critical counts used in canadidate selection
        XCTAssertEqual(BuildPair.all.count, 24)
        XCTAssertEqual(BuildPair.allExceptLatestSwiftVersion.count, 18)
    }

    func test_BuildPair_Equatable() throws {
        XCTAssertEqual(BuildPair(.iOS, .init(5, 3, 0)),
                       BuildPair(.iOS, .init(5, 3, 3)))
        XCTAssertFalse(BuildPair(.iOS, .init(5, 3, 0))
                       == BuildPair(.iOS, .init(5, 4, 0)))
        XCTAssertFalse(BuildPair(.iOS, .init(5, 3, 0))
                       == BuildPair(.tvos, .init(5, 3, 0)))
    }

    func test_BuildPair_Hashable() throws {
        let set = Set([BuildPair(.iOS, .init(5, 3, 0))])
        XCTAssertTrue(set.contains(BuildPair(.iOS, .init(5, 3, 3))))
        XCTAssertFalse(set.contains(BuildPair(.iOS, .init(5, 4, 0))))
        XCTAssertFalse(set.contains(BuildPair(.macosSpm, .init(5, 3, 0))))
    }

    func test_issue_1065() async throws {
        // Regression test for
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1065
        // addressing a problem with findMissingBuilds not ignoring
        // Swift patch versions.
        // setup
        let pkgId = UUID()
        let versionId = UUID()
        do {  // save package with a different Swift patch version
              // (5.7.1 when SwiftVersion.v3 is "5.7.0")
            let p = Package(id: pkgId, url: "1")
            try await p.save(on: app.db)
            let v = try Version(id: versionId,
                                package: p,
                                latest: .release,
                                reference: .tag(1, 2, 3))
            try await v.save(on: app.db)
            try await Build(id: UUID(),
                            version: v,
                            platform: .iOS,
                            status: .ok,
                            swiftVersion: .v1.incrementingPatchVersion()).save(on: app.db)
        }

        // MUT
        let res = try await findMissingBuilds(app.db, packageId: pkgId)
        XCTAssertEqual(res.count, 1)
        let triggerInfo = try XCTUnwrap(res.first)
        XCTAssertEqual(triggerInfo.pairs.count, 23)
        XCTAssertTrue(!triggerInfo.pairs.contains(.init(.iOS, .v1)))
    }

}
