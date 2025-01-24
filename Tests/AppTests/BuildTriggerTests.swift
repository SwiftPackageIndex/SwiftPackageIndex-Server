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

import XCTest

@testable import App

import Dependencies
import Fluent
import NIOConcurrencyHelpers
import SPIManifest
import SQLKit
import Vapor


class BuildTriggerTests: AppTestCase {

    func test_BuildTriggerInfo_emptyPair() throws {
        XCTAssertNotNil(BuildTriggerInfo(versionId: .id0, buildPairs: Set([BuildPair(.iOS, .v1)])))
        XCTAssertNil(BuildTriggerInfo(versionId: .id0, buildPairs: []))
    }

    func test_fetchBuildCandidates_missingBuilds() async throws {
        try await withDependencies {
            $0.environment.buildTriggerAllowList = { [] }
        } operation: {
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
                for pair in BuildPair.all {
                    try await Build(id: UUID(),
                                    version: v,
                                    platform: pair.platform,
                                    status: .ok,
                                    swiftVersion: pair.swiftVersion)
                    .save(on: app.db)
                }
            }
            // save two packages with partially completed builds
            for id in [pkgIdIncomplete1, pkgIdIncomplete2] {
                let p = Package(id: id, url: id.uuidString.url)
                try await p.save(on: app.db)
                for kind in [Version.Kind.defaultBranch, .release] {
                    let v = try Version(package: p,
                                        latest: kind,
                                        reference: kind == .release
                                        ? .tag(1, 2, 3)
                                        : .branch("main"))
                    try await v.save(on: app.db)
                    for pair in BuildPair.all
                        .dropFirst() // skip one platform to create a build gap
                    {
                        try await Build(id: UUID(),
                                        version: v,
                                        platform: pair.platform,
                                        status: .ok,
                                        swiftVersion: pair.swiftVersion)
                        .save(on: app.db)
                    }
                }
            }

            // MUT
            let ids = try await fetchBuildCandidates(app.db)

            // validate
            XCTAssertEqual(ids, [pkgIdIncomplete1, pkgIdIncomplete2])
        }
    }

    func test_fetchBuildCandidates_noBuilds() async throws {
        // Test finding build candidate without any builds (essentially
        // testing the `LEFT` in `LEFT JOIN builds`)
        try await withDependencies {
            $0.environment.buildTriggerAllowList = { [] }
        } operation: {
            // setup
            // save package without any builds
            let pkgId = UUID()
            let p = Package(id: pkgId, url: pkgId.uuidString.url)
            try await p.save(on: app.db)
            for kind in [Version.Kind.defaultBranch, .release] {
                let v = try Version(package: p,
                                    latest: kind,
                                    reference: kind == .release
                                    ? .tag(1, 2, 3)
                                    : .branch("main"))
                try await v.save(on: app.db)
            }

            // MUT
            let ids = try await fetchBuildCandidates(app.db)

            // validate
            XCTAssertEqual(ids, [pkgId])
        }
    }

    func test_fetchBuildCandidates_exceptLatestSwiftVersion() async throws {
        try await withDependencies {
            $0.environment.buildTriggerAllowList = { [] }
        } operation: {
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
    }

    func test_fetchBuildCandidates_priorityIDs() async throws {
        // Ensure allow-listed IDs can be prioritised. See
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2159
        // for details
        // setup
        try await withDependencies {
            $0.environment.buildTriggerAllowList = { [.id1] }
        } operation: {
            // save two packages with partially completed builds
            for id in [UUID.id0, .id1] {
                let p = Package(id: id, url: id.uuidString.url)
                try await p.save(on: app.db)
                for kind in [Version.Kind.defaultBranch, .release] {
                    let v = try Version(package: p,
                                        latest: kind,
                                        reference: kind == .release
                                        ? .tag(1, 2, 3)
                                        : .branch("main"))
                    try await v.save(on: app.db)
                    for pair in BuildPair.all
                        .dropFirst() // skip one platform to create a build gap
                    {
                        try await Build(id: UUID(),
                                        version: v,
                                        platform: pair.platform,
                                        status: .ok,
                                        swiftVersion: pair.swiftVersion)
                        .save(on: app.db)
                    }
                }
            }

            // MUT
            let ids = try await fetchBuildCandidates(app.db)

            // validate
            XCTAssertEqual(ids, [.id1, .id0])
        }
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
            for platform in Build.Platform.allActive
                .filter({ $0 != droppedPlatform }) // skip one platform to create a build gap
            {
                for swiftVersion in SwiftVersion.allActive {
                    try await Build(id: UUID(),
                                    version: v,
                                    platform: platform,
                                    status: .ok,
                                    swiftVersion: swiftVersion)
                    .save(on: app.db)
                }
            }
        }

        // MUT
        let res = try await findMissingBuilds(app.db, packageId: pkgId)
        let expectedPairs = Set(SwiftVersion.allActive.map { BuildPair(droppedPlatform, $0) })
        XCTAssertEqual(res, [.init(versionId: versionId,
                                   buildPairs: expectedPairs,
                                   reference: .tag(1, 2, 3))!])
    }

    func test_BuildPair_manifestSwiftVersion() {
        // Ensure all active versions can be converted (are non-nil)
        for v in SwiftVersion.allActive {
            XCTAssertTrue(BuildPair(.iOS, v).manifestSwiftVersion != nil,
                          "\(v) could not be converted to a SPIManifest Swift version")
        }
        // Check the values specifically (which we can't easily do in the loop above)
        XCTAssertEqual(BuildPair(.iOS, .v5_8).manifestSwiftVersion, .v5_8)
        XCTAssertEqual(BuildPair(.iOS, .v5_9).manifestSwiftVersion, .v5_9)
        XCTAssertEqual(BuildPair(.iOS, .v5_10).manifestSwiftVersion, .v5_10)
    }

    func test_SPIManifest_docPairs() throws {
        do {
            let manifest = try SPIManifest.Manifest(yml: """
                                version: 1
                                builder:
                                  configs:
                                  - documentation_targets: [t0]
                                """)
            XCTAssertEqual(manifest.docPairs, [.init(.macosSpm, .v6_0)])
        }
        do {
            let manifest = try SPIManifest.Manifest(yml: """
                                version: 1
                                builder:
                                  configs:
                                  - documentation_targets: [t0]
                                    platform: ios
                                    swift_version: 5.8
                                """)
            XCTAssertEqual(manifest.docPairs, [.init(.iOS, .v5_8)])
        }
        do {
            let manifest = try SPIManifest.Manifest(yml: """
                                # NB: this is not a currently supported config, just testing potential future behaviour
                                version: 1
                                builder:
                                  configs:
                                  - documentation_targets: [t0]
                                    platform: ios
                                    swift_version: 5.8
                                  - documentation_targets: [t0]
                                    platform: macos-spm
                                    swift_version: 5.9
                                """)
            XCTAssertEqual(manifest.docPairs, [.init(.iOS, .v5_8), .init(.macosSpm, .v5_9)])
        }
    }

    func test_findMissingBuilds_docPairs() async throws {
        // setup
        let pkgId = UUID()
        let versionId = UUID()
        do {  // save package with partially completed builds
            let p = Package(id: pkgId, url: "1")
            try await p.save(on: app.db)
            let v = try Version(id: versionId,
                                package: p,
                                latest: .release,
                                reference: .tag(1, 2, 3),
                                spiManifest: .init(yml: """
                                version: 1
                                builder:
                                  configs:
                                  - documentation_targets: [t0]
                                """))
            try await v.save(on: app.db)
            for platform in Build.Platform.allActive
                .filter({ $0 != .macosSpm }) // skip macosSpm platform to create a build gap
            {
                for swiftVersion in SwiftVersion.allActive {
                    try await Build(id: UUID(),
                                    version: v,
                                    platform: platform,
                                    status: .ok,
                                    swiftVersion: swiftVersion)
                    .save(on: app.db)
                }
            }
        }

        // MUT
        let res = try await findMissingBuilds(app.db, packageId: pkgId)
        let expectedPairs = Set(SwiftVersion.allActive.map { BuildPair(.macosSpm, $0) })
        XCTAssertEqual(res, [.init(versionId: versionId,
                                   buildPairs: expectedPairs,
                                   docPairs: .init([.init(.macosSpm, .v6_0)]),
                                   reference: .tag(1, 2, 3))!])
    }

    func test_triggerBuildsUnchecked() async throws {
        let queries = QueueIsolated<[Gitlab.Builder.PostDTO]>([])
        try await withDependencies {
            $0.environment.awsDocsBucket = { "awsDocsBucket" }
            $0.environment.builderToken = { "builder token" }
            $0.environment.buildTimeout = { 10 }
            $0.environment.gitlabPipelineToken = { "pipeline token" }
            $0.environment.siteURL = { "http://example.com" }
            $0.buildSystem.triggerBuild = BuildSystemClient.liveValue.triggerBuild
            $0.httpClient.post = { @Sendable _, _, body in
                let body = try XCTUnwrap(body)
                let query = try URLEncodedFormDecoder().decode(Gitlab.Builder.PostDTO.self, from: body)
                queries.withValue { $0.append(query) }
                return try .created(jsonEncode: Gitlab.Builder.Response(webUrl: "http://web_url"))
            }
        } operation: {
            // setup
            let versionId = UUID()
            do {  // save package with partially completed builds
                let p = Package(id: UUID(), url: "2")
                try await p.save(on: app.db)
                let v = try Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
                try await v.save(on: app.db)
            }
            let triggers = [BuildTriggerInfo(versionId: versionId,
                                             buildPairs: [BuildPair(.iOS, .v1)])!]

            // MUT
            try await triggerBuildsUnchecked(on: app.db,
                                             client: app.client,
                                             triggers: triggers)

            // validate
            // ensure Gitlab requests go out
            XCTAssertEqual(queries.count, 1)
            XCTAssertEqual(queries.value.map { $0.variables["VERSION_ID"] }, [versionId.uuidString])
            XCTAssertEqual(queries.value.map { $0.variables["BUILD_PLATFORM"] }, ["ios"])
            XCTAssertEqual(queries.value.map { $0.variables["SWIFT_VERSION"] }, ["5.8"])

            // ensure the Build stubs is created to prevent re-selection
            let v = try await Version.find(versionId, on: app.db)
            try await v?.$builds.load(on: app.db)
            XCTAssertEqual(v?.builds.count, 1)
            XCTAssertEqual(v?.builds.map(\.status), [.triggered])
            XCTAssertEqual(v?.builds.map(\.jobUrl), ["http://web_url"])
        }
    }

    func test_triggerBuildsUnchecked_supported() async throws {
        // Explicitly test the full range of all currently triggered platforms and swift versions
        let queries = QueueIsolated<[Gitlab.Builder.PostDTO]>([])
        try await withDependencies {
            $0.environment.awsDocsBucket = { "awsDocsBucket" }
            $0.environment.builderToken = { "builder token" }
            $0.environment.buildTimeout = { 10 }
            $0.environment.buildTriggerAllowList = { [] }
            $0.environment.gitlabPipelineToken = { "pipeline token" }
            $0.environment.siteURL = { "http://example.com" }
            $0.buildSystem.triggerBuild = BuildSystemClient.liveValue.triggerBuild
            $0.httpClient.post = { @Sendable _, _, body in
                let body = try XCTUnwrap(body)
                let query = try URLEncodedFormDecoder().decode(Gitlab.Builder.PostDTO.self, from: body)
                queries.withValue { $0.append(query) }
                return try .created(jsonEncode: Gitlab.Builder.Response(webUrl: "http://web_url"))
            }
        } operation: {
            // setup
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
                                             client: app.client,
                                             triggers: triggers)

            // validate
            // ensure Gitlab requests go out
            XCTAssertEqual(queries.count, 27)
            XCTAssertEqual(queries.value.map { $0.variables["VERSION_ID"] },
                           Array(repeating: versionId.uuidString, count: 27))
            let buildPlatforms = queries.value.compactMap { $0.variables["BUILD_PLATFORM"] }
            XCTAssertEqual(Dictionary(grouping: buildPlatforms, by: { $0 })
                .mapValues(\.count),
                           ["ios": 4,
                            "macos-spm": 4,
                            "macos-xcodebuild": 4,
                            "linux": 4,
                            "watchos": 4,
                            "visionos": 3,
                            "tvos": 4])
            let swiftVersions = queries.value.compactMap { $0.variables["SWIFT_VERSION"] }
            XCTAssertEqual(Dictionary(grouping: swiftVersions, by: { $0 })
                .mapValues(\.count),
                           [SwiftVersion.v1.description(droppingZeroes: .patch): 6,
                            SwiftVersion.v2.description(droppingZeroes: .patch): 7,
                            SwiftVersion.v3.description(droppingZeroes: .patch): 7,
                            SwiftVersion.v4.description(droppingZeroes: .patch): 7])

            // ensure the Build stubs are created to prevent re-selection
            let v = try await Version.find(versionId, on: app.db)
            try await v?.$builds.load(on: app.db)
            XCTAssertEqual(v?.builds.count, 27)

            // ensure re-selection is empty
            let candidates = try await fetchBuildCandidates(app.db)
            XCTAssertEqual(candidates, [])
        }
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
        let queries = QueueIsolated<[Gitlab.Builder.PostDTO]>([])
        try await withDependencies {
            $0.environment.awsDocsBucket = { "awsDocsBucket" }
            $0.environment.builderToken = { "builder token" }
            $0.environment.buildTimeout = { 10 }
            $0.environment.gitlabPipelineToken = { "pipeline token" }
            $0.environment.siteURL = { "http://example.com" }
            $0.buildSystem.triggerBuild = BuildSystemClient.liveValue.triggerBuild
            $0.httpClient.post = { @Sendable _, _, body in
                let body = try XCTUnwrap(body)
                let query = try URLEncodedFormDecoder().decode(Gitlab.Builder.PostDTO.self, from: body)
                queries.withValue { $0.append(query) }
                return try .created(jsonEncode: Gitlab.Builder.Response(webUrl: "http://web_url"))
            }
        } operation: {
            // setup
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
                                             buildPairs: [BuildPair(.macosSpm, .v3)])!]

            // MUT
            try await triggerBuildsUnchecked(on: app.db,
                                             client: app.client,
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
    }

    func test_triggerBuilds_checked() async throws {
        // Ensure we respect the pipeline limit when triggering builds
        let triggerCount = QueueIsolated(0)
        try await withDependencies {
            $0.environment.allowBuildTriggers = { true }
            $0.environment.awsDocsBucket = { "awsDocsBucket" }
            $0.environment.builderToken = { "builder token" }
            $0.environment.buildTimeout = { 10 }
            $0.environment.buildTriggerAllowList = { [] }
            $0.environment.buildTriggerDownscaling = { 1 }
            $0.environment.gitlabPipelineLimit = { 300 }
            $0.environment.gitlabPipelineToken = { "pipeline token" }
            $0.environment.random = { @Sendable _ in 0 }
            $0.environment.siteURL = { "http://example.com" }
            // Use live dependency but replace actual client with a mock so we can
            // assert on the details being sent without actually making a request
            $0.buildSystem.triggerBuild = BuildSystemClient.liveValue.triggerBuild
            $0.httpClient.post = { @Sendable _, _, body in
                triggerCount.increment()
                return try .created(jsonEncode: Gitlab.Builder.Response(webUrl: "http://web_url"))
            }
        } operation: {
            do {  // fist run: we are at capacity and should not be triggering more builds
                try await withDependencies {
                    $0.buildSystem.getStatusCount = { @Sendable _ in 300 }
                } operation: {
                    let pkgId = UUID()
                    let versionId = UUID()
                    let p = Package(id: pkgId, url: "1")
                    try await p.save(on: app.db)
                    try await Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
                        .save(on: app.db)

                    // MUT
                    try await triggerBuilds(on: app.db,
                                            client: app.client,
                                            mode: .packageId(pkgId, force: false))

                    // validate
                    XCTAssertEqual(triggerCount.value, 0)
                    // ensure no build stubs have been created either
                    let v = try await Version.find(versionId, on: app.db)
                    try await v?.$builds.load(on: app.db)
                    XCTAssertEqual(v?.builds.count, 0)
                }
            }

            triggerCount.setValue(0)

            do {  // second run: we are just below capacity and allow more builds to be triggered
                try await withDependencies {
                    $0.buildSystem.getStatusCount = { @Sendable _ in 299 }
                } operation: {
                    let pkgId = UUID()
                    let versionId = UUID()
                    let p = Package(id: pkgId, url: "2")
                    try await p.save(on: app.db)
                    try await Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
                        .save(on: app.db)

                    // MUT
                    try await triggerBuilds(on: app.db,
                                            client: app.client,
                                            mode: .packageId(pkgId, force: false))

                    // validate
                    XCTAssertEqual(triggerCount.value, 27)
                    // ensure builds are now in progress
                    let v = try await Version.find(versionId, on: app.db)
                    try await v?.$builds.load(on: app.db)
                    XCTAssertEqual(v?.builds.count, 27)
                }
            }

            triggerCount.setValue(0)

            do {  // third run: we are at capacity and using the `force` flag
                try await withDependencies {
                    $0.buildSystem.getStatusCount = { @Sendable _ in 300 }
                } operation: {
                    let pkgId = UUID()
                    let versionId = UUID()
                    let p = Package(id: pkgId, url: "3")
                    try await p.save(on: app.db)
                    try await Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
                        .save(on: app.db)

                    // MUT
                    try await triggerBuilds(on: app.db,
                                            client: app.client,
                                            mode: .packageId(pkgId, force: true))

                    // validate
                    XCTAssertEqual(triggerCount.value, 27)
                    // ensure builds are now in progress
                    let v = try await Version.find(versionId, on: app.db)
                    try await v?.$builds.load(on: app.db)
                    XCTAssertEqual(v?.builds.count, 27)
                }
            }
        }
    }

    func test_triggerBuilds_multiplePackages() async throws {
        // Ensure we respect the pipeline limit when triggering builds for multiple package ids
        let triggerCount = QueueIsolated(0)
        try await withDependencies {
            $0.buildSystem.getStatusCount = { @Sendable _ in
                299 + triggerCount.value
            }
            $0.environment.allowBuildTriggers = { true }
            $0.environment.awsDocsBucket = { "awsDocsBucket" }
            $0.environment.builderToken = { "builder token" }
            $0.environment.buildTimeout = { 10 }
            $0.environment.buildTriggerAllowList = { [] }
            $0.environment.buildTriggerDownscaling = { 1 }
            $0.environment.buildTriggerLatestSwiftVersionDownscaling = { 1 }
            $0.environment.gitlabPipelineLimit = { 300 }
            $0.environment.gitlabPipelineToken = { "pipeline token" }
            $0.environment.random = { @Sendable _ in 0 }
            $0.environment.siteURL = { "http://example.com" }
            $0.buildSystem.triggerBuild = BuildSystemClient.liveValue.triggerBuild
            $0.httpClient.post = { @Sendable _, _, body in
                triggerCount.increment()
                return try .created(jsonEncode: Gitlab.Builder.Response(webUrl: "http://web_url"))
            }
        } operation: {
            // setup
            let pkgIds = [UUID(), UUID()]
            for id in pkgIds {
                let p = Package(id: id, url: id.uuidString.url)
                try await p.save(on: app.db)
                try await Version(id: UUID(), package: p, latest: .defaultBranch, reference: .branch("main"))
                    .save(on: app.db)
            }

            // MUT
            try await triggerBuilds(on: app.db,
                                    client: app.client,
                                    mode: .limit(4))

            // validate - only the first batch must be allowed to trigger
            XCTAssertEqual(triggerCount.value, 27)
        }
    }

    func test_triggerBuilds_trimming() async throws {
        try await withDependencies {
            $0.buildSystem.getStatusCount = { @Sendable _ in 100 }
            $0.environment.allowBuildTriggers = { true }
            $0.environment.awsDocsBucket = { "awsDocsBucket" }
            $0.environment.builderToken = { "builder token" }
            $0.environment.buildTriggerAllowList = { [] }
            $0.environment.buildTriggerDownscaling = { 1 }
            $0.environment.gitlabPipelineLimit = { 300 }
            $0.environment.gitlabPipelineToken = { "pipeline token" }
            $0.environment.random = { @Sendable _ in 0 }
            $0.environment.siteURL = { "http://example.com" }
        } operation: {
            // Ensure we trim builds as part of triggering
            // setup

            let client = MockClient { _, _ in }

            let p = Package(id: .id0, url: "2")
            try await p.save(on: app.db)
            let v = try Version(id: .id1, package: p, latest: nil, reference: .branch("main"))
            try await v.save(on: app.db)
            try await Build(id: .id2, version: v, platform: .iOS, status: .triggered, swiftVersion: .v2)
                .save(on: app.db)
            // shift createdAt back to make build eligible from trimming
            try await updateBuildCreatedAt(id: .id2, addTimeInterval: -.hours(5), on: app.db)
            let db = app.db
            try await XCTAssertEqualAsync(try await Build.query(on: db).count(), 1)

            // MUT
            try await triggerBuilds(on: app.db,
                                    client: client,
                                    mode: .packageId(p.id!, force: false))

            // validate
            let count = try await Build.query(on: app.db).count()
            XCTAssertEqual(count, 0)
        }
    }

    func test_triggerBuilds_error() async throws {
        // Ensure we trim builds as part of triggering
        let triggerCount = QueueIsolated(0)
        try await withDependencies {
            $0.buildSystem.getStatusCount = { @Sendable _ in 100 }
            $0.environment.allowBuildTriggers = { true }
            $0.environment.awsDocsBucket = { "awsDocsBucket" }
            $0.environment.builderToken = { "builder token" }
            $0.environment.buildTimeout = { 10 }
            $0.environment.buildTriggerAllowList = { [] }
            $0.environment.buildTriggerDownscaling = { 1 }
            $0.environment.gitlabPipelineLimit = { 300 }
            $0.environment.gitlabPipelineToken = { "pipeline token" }
            $0.environment.random = { @Sendable _ in 0 }
            $0.environment.siteURL = { "http://example.com" }
            $0.buildSystem.triggerBuild = BuildSystemClient.liveValue.triggerBuild
            $0.httpClient.post = { @Sendable _, _, body in
                defer { triggerCount.increment() }
                // let the 5th trigger succeed to ensure we don't early out on errors
                if triggerCount.value == 5 {
                    return try .created(jsonEncode: Gitlab.Builder.Response(webUrl: "http://web_url"))
                } else {
                    struct Response: Content { var message: String }
                    return try .tooManyRequests(jsonEncode: Response(message: "Too many pipelines created in the last minute. Try again later."))
                }
            }
        } operation: {
            // setup
            let p = Package(id: .id0, url: "1")
            try await p.save(on: app.db)
            let v = try Version(id: .id1, package: p, latest: .defaultBranch, reference: .branch("main"))
            try await v.save(on: app.db)

            // MUT
            try await triggerBuilds(on: app.db,
                                    client: app.client,
                                    mode: .packageId(.id0, force: false))

            // validate that one build record is saved, for the successful trigger
            let count = try await Build.query(on: app.db).count()
            XCTAssertEqual(count, 1)
        }
    }

    func test_buildTriggerCandidatesSkipLatestSwiftVersion() throws {
        @Dependency(\.environment) var environment
        withDependencies {
            // Test downscaling set to 10%
            $0.environment.buildTriggerLatestSwiftVersionDownscaling = { 0.1 }
        } operation: {
            // Roll just below threshold should keep latest Swift version
            withDependencies {
                $0.environment.random = { @Sendable _ in 0.09 }
            } operation: {
                XCTAssertEqual(environment.buildTriggerCandidatesWithLatestSwiftVersion, true)
            }
            // Roll on threshold should skip latest Swift version
            withDependencies {
                $0.environment.random = { @Sendable _ in 0.1 }
            } operation: {
                XCTAssertEqual(environment.buildTriggerCandidatesWithLatestSwiftVersion, false)
            }
            // Roll just above threshold should skip latest Swift version
            withDependencies {
                $0.environment.random = { @Sendable _ in 0.11 }
            } operation: {
                XCTAssertEqual(environment.buildTriggerCandidatesWithLatestSwiftVersion, false)
            }
        }

        withDependencies {
            // Set downscaling to 0 in order to fully skip latest Swift version based candidate selection
            $0.environment.buildTriggerLatestSwiftVersionDownscaling = { 0 }
        } operation: {
            withDependencies {
                $0.environment.random = { @Sendable _ in 0 }
            } operation: {
                XCTAssertEqual(environment.buildTriggerCandidatesWithLatestSwiftVersion, false)
            }
            withDependencies {
                $0.environment.random = { @Sendable _ in 0.5 }
            } operation: {
                XCTAssertEqual(environment.buildTriggerCandidatesWithLatestSwiftVersion, false)
            }
            withDependencies {
                $0.environment.random = { @Sendable _ in 1 }
            } operation: {
                XCTAssertEqual(environment.buildTriggerCandidatesWithLatestSwiftVersion, false)
            }
        }

        withDependencies {
            // Set downscaling to 1 in order to fully disable any downscaling
            $0.environment.buildTriggerLatestSwiftVersionDownscaling = { 1 }
        } operation: {
            withDependencies {
                $0.environment.random = { @Sendable _ in 0 }
            } operation: {
                XCTAssertEqual(environment.buildTriggerCandidatesWithLatestSwiftVersion, true)
            }
            withDependencies {
                $0.environment.random = { @Sendable _ in 0.5 }
            } operation: {
                XCTAssertEqual(environment.buildTriggerCandidatesWithLatestSwiftVersion, true)
            }
            withDependencies {
                $0.environment.random = { @Sendable _ in 1 }
            } operation: {
                XCTAssertEqual(environment.buildTriggerCandidatesWithLatestSwiftVersion, true)
            }
        }
    }

    func test_override_switch() async throws {
        // Ensure we don't trigger if the override is off
        let triggerCount = QueueIsolated(0)
        try await withDependencies {
            $0.buildSystem.getStatusCount = { @Sendable _ in 100 }
            $0.environment.awsDocsBucket = { "awsDocsBucket" }
            $0.environment.builderToken = { "builder token" }
            $0.environment.buildTimeout = { 10 }
            $0.environment.buildTriggerAllowList = { [] }
            $0.environment.buildTriggerDownscaling = { 1 }
            $0.environment.gitlabPipelineLimit = { Constants.defaultGitlabPipelineLimit }
            $0.environment.gitlabPipelineToken = { "pipeline token" }
            $0.environment.random = { @Sendable _ in 0 }
            $0.environment.siteURL = { "http://example.com" }
            $0.buildSystem.triggerBuild = BuildSystemClient.liveValue.triggerBuild
            $0.httpClient.post = { @Sendable _, _, body in
                triggerCount.increment()
                return try .created(jsonEncode: Gitlab.Builder.Response(webUrl: "http://web_url"))
            }
        } operation: {
            // setup
            try await withDependencies {
                // confirm that the off switch prevents triggers
                $0.environment.allowBuildTriggers = { false }
            } operation: {
                let pkgId = UUID()
                let versionId = UUID()
                let p = Package(id: pkgId, url: "1")
                try await p.save(on: app.db)
                try await Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
                    .save(on: app.db)

                // MUT
                try await triggerBuilds(on: app.db,
                                        client: app.client,
                                        mode: .packageId(pkgId, force: false))

                // validate
                XCTAssertEqual(triggerCount.value, 0)
            }

            triggerCount.setValue(0)

            try await withDependencies {
                // flipping the switch to on should allow triggers to proceed
                $0.environment.allowBuildTriggers = { true }
            } operation: {
                let pkgId = UUID()
                let versionId = UUID()
                let p = Package(id: pkgId, url: "2")
                try await p.save(on: app.db)
                try await Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
                    .save(on: app.db)

                // MUT
                try await triggerBuilds(on: app.db,
                                        client: app.client,
                                        mode: .packageId(pkgId, force: false))

                // validate
                XCTAssertEqual(triggerCount.value, 27)
            }
        }
    }

    func test_downscaling() async throws {
        // Test build trigger downscaling behaviour
        let triggerCount = QueueIsolated(0)
        try await withDependencies {
            $0.buildSystem.getStatusCount = { @Sendable _ in 100 }
            $0.environment.allowBuildTriggers = { true }
            $0.environment.awsDocsBucket = { "awsDocsBucket" }
            $0.environment.builderToken = { "builder token" }
            $0.environment.buildTimeout = { 10 }
            $0.environment.buildTriggerAllowList = { [] }
            $0.environment.buildTriggerDownscaling = { 0.05 } // 5% downscaling rate
            $0.environment.gitlabPipelineLimit = { Constants.defaultGitlabPipelineLimit }
            $0.environment.gitlabPipelineToken = { "pipeline token" }
            $0.environment.siteURL = { "http://example.com" }
            $0.buildSystem.triggerBuild = BuildSystemClient.liveValue.triggerBuild
            $0.httpClient.post = { @Sendable _, _, body in
                triggerCount.increment()
#warning("can we simplify this?")
                return try .created(jsonEncode: Gitlab.Builder.Response(webUrl: "http://web_url"))
            }
        } operation: {
            // confirm that bad luck prevents triggers
            try await withDependencies {
                $0.environment.random = { @Sendable _ in 0.05 } // rolling a 0.05 ... so close!
            } operation: {
                let pkgId = UUID()
                let versionId = UUID()
                let p = Package(id: pkgId, url: "1")
                try await p.save(on: app.db)
                try await Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
                    .save(on: app.db)

                // MUT
                try await triggerBuilds(on: app.db,
                                        client: app.client,
                                        mode: .packageId(pkgId, force: false))

                // validate
                XCTAssertEqual(triggerCount.value, 0)
            }

            triggerCount.setValue(0)

            // if we get lucky however...
            try await withDependencies {
                $0.environment.random = { @Sendable _ in 0.049 } // rolling a 0.049 gets you in
            } operation: {
                let pkgId = UUID()
                let versionId = UUID()
                let p = Package(id: pkgId, url: "2")
                try await p.save(on: app.db)
                try await Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
                    .save(on: app.db)

                // MUT
                try await triggerBuilds(on: app.db,
                                        client: app.client,
                                        mode: .packageId(pkgId, force: false))

                // validate
                XCTAssertEqual(triggerCount.value, 27)
            }
        }
    }

    func test_downscaling_allow_list_override() async throws {
        try await withDependencies {
            $0.buildSystem.getStatusCount = { @Sendable _ in 100 }
            $0.environment.allowBuildTriggers = { true }
            $0.environment.awsDocsBucket = { "awsDocsBucket" }
            $0.environment.builderToken = { "builder token" }
            $0.environment.buildTimeout = { 10 }
            $0.environment.buildTriggerAllowList = { [.id0] }
            $0.environment.buildTriggerDownscaling = { 0.05 } // 5% downscaling rate
            $0.environment.gitlabPipelineLimit = { Constants.defaultGitlabPipelineLimit }
            $0.environment.gitlabPipelineToken = { "pipeline token" }
            $0.environment.siteURL = { "http://example.com" }
            // Use live dependency but replace actual client with a mock so we can
            // assert on the details being sent without actually making a request
            $0.buildSystem.triggerBuild = { @Sendable buildId, cloneURL, isDocBuild, platform, ref, swiftVersion, versionID in
                try await Gitlab.Builder.triggerBuild(buildId: buildId,
                                                      cloneURL: cloneURL,
                                                      isDocBuild: isDocBuild,
                                                      platform: platform,
                                                      reference: ref,
                                                      swiftVersion: swiftVersion,
                                                      versionID: versionID)
            }
        } operation: {
            // Test build trigger downscaling behaviour for allow-listed packages
            // setup
            var triggerCount = 0
            let client = MockClient { _, res in
                triggerCount += 1
                try? res.content.encode(
                    Gitlab.Builder.Response(webUrl: "http://web_url")
                )
            }

            // confirm that we trigger even when rolling above the threshold
            try await withDependencies {
                $0.environment.random = { @Sendable _ in 0.051 }
            } operation: {
                let versionId = UUID()
                let p = Package(id: .id0, url: "https://github.com/foo/bar.git")
                try await p.save(on: app.db)
                try await Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
                    .save(on: app.db)

                // MUT
                try await triggerBuilds(on: app.db,
                                        client: client,
                                        mode: .packageId(.id0, force: false))

                // validate
                XCTAssertEqual(triggerCount, 27)
            }
        }
    }

    func test_trimBuilds_significant_version() async throws {
        // setup
        let pkgId = UUID()
        let p = Package(id: pkgId, url: "1")
        try await p.save(on: app.db)
        // significant version - latest = 'default_branch'
        let v = try Version(package: p, latest: .defaultBranch)
        try await v.save(on: app.db)

        do {  // set up builds
            // old triggered build (delete)
            try await Build(id: .id0, version: v, platform: .iOS, status: .triggered, swiftVersion: .v2)
                .save(on: app.db)
            // new triggered build (keep)
            try await Build(id: .id1, version: v, platform: .iOS, status: .triggered, swiftVersion: .v3)
                .save(on: app.db)
            // old non-triggered build (keep)
            try await Build(id: .id2, version: v, platform: .iOS, status: .ok, swiftVersion: .v1)
                .save(on: app.db)

            // make old builds "old" by resetting "created_at" to before the trimBuilds window (4h)
            try await updateBuildCreatedAt(id: .id0, addTimeInterval: -.hours(5), on: app.db)
            try await updateBuildCreatedAt(id: .id2, addTimeInterval: -.hours(5), on: app.db)
        }

        let db = app.db
        try await XCTAssertEqualAsync(try await Build.query(on: db).count(), 3)

        // MUT
        let deleteCount = try await trimBuilds(on: app.db)

        // validate
        XCTAssertEqual(deleteCount, 1)
        let app = self.app!
        try await XCTAssertEqualAsync(try await Build.query(on: app.db).all().map(\.id), [.id1, .id2])
    }

    func test_trimBuilds_non_significant_version() async throws {
        // setup
        let pkgId = UUID()
        let p = Package(id: pkgId, url: "1")
        try await p.save(on: app.db)
        // not a significant version - latest = nil
        let v = try Version(package: p, latest: nil)
        try await v.save(on: app.db)

        do {  // set up builds
            // old triggered build (delete)
            try await Build(id: .id0, version: v, platform: .iOS, status: .triggered, swiftVersion: .v2)
                .save(on: app.db)
            // new triggered build (keep)
            try await Build(id: .id1, version: v, platform: .iOS, status: .triggered, swiftVersion: .v3)
                .save(on: app.db)
            // old non-triggered build (delete)
            try await Build(id: .id2, version: v, platform: .iOS, status: .ok, swiftVersion: .v1)
                .save(on: app.db)

            // make old builds "old" by resetting "created_at" to before the trimBuilds window (4h)
            try await updateBuildCreatedAt(id: .id0, addTimeInterval: -.hours(5), on: app.db)
            try await updateBuildCreatedAt(id: .id2, addTimeInterval: -.hours(5), on: app.db)
        }

        let db = app.db
        try await XCTAssertEqualAsync(try await Build.query(on: db).count(), 3)

        // MUT
        let deleteCount = try await trimBuilds(on: app.db)

        // validate
        XCTAssertEqual(deleteCount, 2)
        let app = self.app!
        try await XCTAssertEqualAsync(try await Build.query(on: app.db).all().map(\.id), [.id1])
    }

    func test_trimBuilds_allVariants() async throws {
        // trimBuilds is acting on three properties with two states each:
        // created_at: within 4h / older
        // status: triggered or infrastructureError / otherwise
        // latest: not null / null
        // This test sets up 8 builds covering all combinations to confirm whether the build is
        // being trimmed or not.
        // setup
        let p = Package(url: "1")
        try await p.save(on: app.db)
        let release = try Version(package: p, latest: .release)
        try await release.save(on: app.db)
        let nonSignificant = try Version(package: p, latest: nil)
        try await nonSignificant.save(on: app.db)

        do {  // set up builds
            try await [
                // ✅ recent, release, ok
                Build(id: .id0, version: release, platform: .iOS, status: .ok, swiftVersion: .latest),
                // ✅ recent, release, triggered
                Build(id: .id1, version: release, platform: .linux, status: .triggered, swiftVersion: .latest),
                // ✅ recent, nonSignificant, ok
                Build(id: .id2, version: nonSignificant, platform: .iOS, status: .ok, swiftVersion: .latest),
                // ✅ recent, nonSignificant, triggered
                Build(id: .id3, version: nonSignificant, platform: .linux, status: .triggered, swiftVersion: .latest),
            ].save(on: app.db)

            let oldBuilds = try [
                // ✅ old, release, ok
                Build(id: .id4, version: release, platform: .watchOS, status: .ok, swiftVersion: .latest),
                // ❌ old, release, triggered
                Build(id: .id5, version: release, platform: .tvOS, status: .triggered, swiftVersion: .latest),
                // ❌ old, nonSignificant, ok
                Build(id: .id6, version: nonSignificant, platform: .watchOS, status: .ok, swiftVersion: .latest),
                // ❌ old, nonSignificant, triggered
                Build(id: .id7, version: nonSignificant, platform: .tvOS, status: .triggered, swiftVersion: .latest),
            ]
            try await oldBuilds.save(on: app.db)

            // make old builds "old" by resetting "created_at" to before the trimBuilds window (4h)
            for id in oldBuilds.map(\.id) {
                try await updateBuildCreatedAt(id: id!, addTimeInterval: -.hours(5), on: app.db)
            }
        }

        let db = app.db
        try await XCTAssertEqualAsync(try await Build.query(on: db).count(), 8)

        // MUT
        let deleteCount = try await trimBuilds(on: app.db)

        // validate
        XCTAssertEqual(deleteCount, 3)
        let app = self.app!
        try await XCTAssertEqualAsync(try await Build.query(on: app.db).all().map(\.id),
                                      [.id0, .id1, .id2, .id3, .id4])
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
        let db = app.db
        try await XCTAssertEqualAsync(try await Build.query(on: db).count(), 1)

        // make build "old" by resetting "created_at"
        try await updateBuildCreatedAt(id: buildId, addTimeInterval: -.hours(4), on: app.db)

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
        let db = app.db
        try await XCTAssertEqualAsync(try await Build.query(on: db).count(), 1)

        // make build "old" by resetting "created_at"
        try await updateBuildCreatedAt(id: buildId, addTimeInterval: -.hours(5), on: app.db)

        // MUT
        deleteCount = try await trimBuilds(on: app.db)

        // validate
        XCTAssertEqual(deleteCount, 1)
        let buildCount = try await Build.query(on: app.db).count()
        XCTAssertEqual(buildCount, 0)
    }

    func test_BuildPair_all() throws {
        // Sanity checks for critical counts used in canadidate selection
        XCTAssertEqual(BuildPair.all.count, 27)
        XCTAssertEqual(BuildPair.all, [
            .init(.iOS, .v5_8),
            .init(.iOS, .v5_9),
            .init(.iOS, .v5_10),
            .init(.iOS, .v6_0),
            .init(.macosSpm, .v5_8),
            .init(.macosSpm, .v5_9),
            .init(.macosSpm, .v5_10),
            .init(.macosSpm, .v6_0),
            .init(.macosXcodebuild, .v5_8),
            .init(.macosXcodebuild, .v5_9),
            .init(.macosXcodebuild, .v5_10),
            .init(.macosXcodebuild, .v6_0),
            .init(.visionOS, .v5_9),
            .init(.visionOS, .v5_10),
            .init(.visionOS, .v6_0),
            .init(.tvOS, .v5_8),
            .init(.tvOS, .v5_9),
            .init(.tvOS, .v5_10),
            .init(.tvOS, .v6_0),
            .init(.watchOS, .v5_8),
            .init(.watchOS, .v5_9),
            .init(.watchOS, .v5_10),
            .init(.watchOS, .v6_0),
            .init(.linux, .v5_8),
            .init(.linux, .v5_9),
            .init(.linux, .v5_10),
            .init(.linux, .v6_0),
        ])
        XCTAssertEqual(BuildPair.allExceptLatestSwiftVersion.count, 20)
    }

    func test_BuildPair_Equatable() throws {
        XCTAssertEqual(BuildPair(.iOS, .init(5, 3, 0)),
                       BuildPair(.iOS, .init(5, 3, 3)))
        XCTAssertFalse(BuildPair(.iOS, .init(5, 3, 0))
                       == BuildPair(.iOS, .init(5, 4, 0)))
        XCTAssertFalse(BuildPair(.iOS, .init(5, 3, 0))
                       == BuildPair(.tvOS, .init(5, 3, 0)))
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
        XCTAssertEqual(triggerInfo.buildPairs.count, 26)
        XCTAssertTrue(!triggerInfo.buildPairs.contains(.init(.iOS, .v1)))
    }

}


private func updateBuildCreatedAt(id: Build.Id, addTimeInterval timeInterval: TimeInterval, on database: Database) async throws {
    let b = try await XCTUnwrapAsync(await Build.find(id, on: database))
    b.createdAt = b.createdAt?.addingTimeInterval(timeInterval)
    try await b.save(on: database)
}


private extension HTTPClient.Response {
    static func tooManyRequests<T: Encodable>(jsonEncode value: T) throws -> Self {
        let data = try JSONEncoder().encode(value)
        return .init(status: .tooManyRequests, body: .init(data: data))
    }
}
