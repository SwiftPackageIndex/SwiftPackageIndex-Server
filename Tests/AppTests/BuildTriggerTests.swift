@testable import App

import XCTest


class BuildTriggerTests: AppTestCase {

    func test_fetchBuildCandidates() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
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

        // MUT
        let ids = try fetchBuildCandidates(app.db, limit: 10).wait()

        // validate
        XCTAssertEqual(ids, [])
    }

}
