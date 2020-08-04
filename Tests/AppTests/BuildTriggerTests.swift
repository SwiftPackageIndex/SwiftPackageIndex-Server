@testable import App

import Vapor
import XCTest


class BuildTriggerTests: AppTestCase {

    func test_fetchBuildCandidates() throws {
        // setup
        let pkgIdComplete = UUID()
        let pkgIdIncomplete = UUID()
        do {  // save package with all builds
            let p = Package(id: pkgIdComplete, url: "1")
            try p.save(on: app.db).wait()
            let v = try Version(package: p, latest: .defaultBranch)
            try v.save(on: app.db).wait()
            try Build.Platform.allActive.forEach { platform in
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
        do {  // save package with partially completed builds
            let p = Package(id: pkgIdIncomplete, url: "2")
            try p.save(on: app.db).wait()
            let v = try Version(package: p, latest: .defaultBranch)
            try v.save(on: app.db).wait()
            try Build.Platform.allActive
                .dropFirst() // skip one platform to create a build gap
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
        let ids = try fetchBuildCandidates(app.db, limit: 10).wait()

        // validate
        XCTAssertEqual(ids, [pkgIdIncomplete])
    }

    func test_findMissingBuilds() throws {
        // setup
        let pkgId = UUID()
        let versionId = UUID()
        do {  // save package with partially completed builds
            let p = Package(id: pkgId, url: "2")
            try p.save(on: app.db).wait()
            let v = try Version(id: versionId, package: p, latest: .defaultBranch)
            try v.save(on: app.db).wait()
            try Build.Platform.allActive
                .dropFirst() // skip one platform to create a build gap
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
        let droppedPlatform = try XCTUnwrap(Build.Platform.allActive.first)
        let expectedPairs = Set(SwiftVersion.allActive.map { BuildPair(droppedPlatform, $0) })
        XCTAssertEqual(res, [.init(versionId, expectedPairs)])
    }

    func test_triggerBuilds() throws {
        // setup
        Current.builderToken = { "builder token" }
        Current.gitlabPipelineToken = { "pipeline token" }
        Current.siteURL = { "http://example.com" }

        let queue = DispatchQueue(label: "serial")
        var queries = [[String: String]]()
        let client = MockClient { req, res in
            queue.sync {
                guard let query = try? req.query.decode([String: String].self) else { return }
                queries.append(query)
            }
        }

        let pkgId = UUID()
        let versionId = UUID()
        do {  // save package with partially completed builds
            let p = Package(id: pkgId, url: "2")
            try p.save(on: app.db).wait()
            let v = try Version(id: versionId, package: p, latest: .defaultBranch, reference: .branch("main"))
            try v.save(on: app.db).wait()
            try Build.Platform.allActive
                .dropFirst() // skip one platform to create a build gap
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
        try triggerBuilds(on: app.db, client: client, packages: [pkgId]).wait()

        // validate
        // ensure Gitlab requests go out
        XCTAssertEqual(queries.count, 5)
        XCTAssertEqual(queries.map { $0["variables[VERSION_ID]"] },
                       Array(repeating: versionId.uuidString, count: 5))
        XCTAssertEqual(queries.map { $0["variables[BUILD_PLATFORM]"] },
                       Array(repeating: "ios", count: 5))
        XCTAssertEqual(queries.compactMap { $0["variables[SWIFT_VERSION]"] }.sorted(),
                       SwiftVersion.allActive.map { "\($0.major).\($0.minor).\($0.patch)" })

        // ensure the Build stubs are created to prevent re-selection
        let v = try Version.find(versionId, on: app.db).wait()
        try v?.$builds.load(on: app.db).wait()
        XCTAssertEqual(v?.builds.count, 25)

        // ensure re-selection is empty
        XCTAssertEqual(try fetchBuildCandidates(app.db, limit: 10).wait(), [])
    }

}
