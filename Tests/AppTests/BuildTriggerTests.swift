@testable import App

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
        XCTFail("implement")
        // ensure Gitlab requests go out
        // ensure the Build stubs are created to prevent re-selection
        // ensure re-selection is empty
    }

}
