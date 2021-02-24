@testable import App

import XCTest


class AnalyzerVersionThrottlingTests: AppTestCase {

    func test_throttle_keep_old() throws {
        // Test keeping old when within throttling window
        // setup
        Current.date = { .t0 }
        let pkg = Package(url: "1")
        try pkg.save(on: app.db).wait()
        let old = try makeVersion(pkg, "sha_old", -23.hours, .branch("main"))
        let new = try makeVersion(pkg, "sha_new", -1.hours, .branch("main"))

        // MUT
        let res = throttle(lastestExistingVersion: old, incoming: [new])

        // validate
        XCTAssertEqual(res, [old])
    }

    func test_throttle_take_new() throws {
        // Test picking new version when old one is outside the window
        // setup
        Current.date = { .t0 }
        let pkg = Package(url: "1")
        try pkg.save(on: app.db).wait()
        let old = try makeVersion(pkg, "sha_old", -26.hours, .branch("main"))
        let new = try makeVersion(pkg, "sha_new", -1.hours, .branch("main"))

        // MUT
        let res = throttle(lastestExistingVersion: old, incoming: [new])

        // validate
        XCTAssertEqual(res, [new])
    }

    func test_throttle_ignore_tags() throws {
        // Test to ensure tags are exempt from throttling
        // setup
        Current.date = { .t0 }
        let pkg = Package(url: "1")
        try pkg.save(on: app.db).wait()
        let old = try makeVersion(pkg, "sha_old", -23.hours, .tag(1, 0, 0))
        let new = try makeVersion(pkg, "sha_new", -1.hours, .tag(2, 0, 0))

        // MUT
        let res = throttle(lastestExistingVersion: old, incoming: [new])

        // validate
        XCTAssertEqual(res, [new])
    }

    func test_throttle_new_package() throws {
        // Test picking up a new package's branch
        // setup
        Current.date = { .t0 }
        let pkg = Package(url: "1")
        try pkg.save(on: app.db).wait()
        let new = try makeVersion(pkg, "sha_new", -1.hours, .branch("main"))

        // MUT
        let res = throttle(lastestExistingVersion: nil, incoming: [new])

        // validate
        XCTAssertEqual(res, [new])
    }

    func test_throttle_branch_ref_change() throws {
        // Test behaviour when changing default branch names
        // setup
        Current.date = { .t0 }
        let pkg = Package(url: "1")
        try pkg.save(on: app.db).wait()
        let old = try makeVersion(pkg, "sha_old", -23.hours, .branch("develop"))
        let new = try makeVersion(pkg, "sha_new", -1.hours, .branch("main"))

        // MUT
        let res = throttle(lastestExistingVersion: old, incoming: [new])

        // validate
        XCTAssertEqual(res, [old])
    }

    func test_throttle_rename() throws {
        // Ensure incoming branch renames are throttled
        // setup
        Current.date = { .t0 }
        let pkg = Package(url: "1")
        try pkg.save(on: app.db).wait()
        let old = try makeVersion(pkg, "sha", -1.hours, .branch("main-old"))
        let new = try makeVersion(pkg, "sha", -1.hours, .branch("main-new"))

        // MUT
        let res = throttle(lastestExistingVersion: old, incoming: [new])

        // validate
        XCTAssertEqual(res, [old])
    }

    func test_throttle_multiple_incoming_branches_keep_old() throws {
        // Test behaviour with multiple incoming branch revisions
        // NB: this is a theoretical scenario, in practise there should only
        // ever be one branch revision among the incoming revisions.
        // setup
        Current.date = { .t0 }
        let pkg = Package(url: "1")
        try pkg.save(on: app.db).wait()
        let old = try makeVersion(pkg, "sha_old", -23.hours, .branch("main"))
        let new0 = try makeVersion(pkg, "sha_new0", -3.hours, .branch("main"))
        let new1 = try makeVersion(pkg, "sha_new1", -2.hours, .branch("main"))
        let new2 = try makeVersion(pkg, "sha_new2", -1.hours, .branch("main"))

        // MUT
        let res = throttle(lastestExistingVersion: old,
                           incoming: [new0, new1, new2].shuffled())

        // validate
        XCTAssertEqual(res, [old])
    }

    func test_throttle_multiple_incoming_branches_take_new() throws {
        // Test behaviour with multiple incoming branch revisions
        // NB: this is a theoretical scenario, in practise there should only
        // ever be one branch revision among the incoming revisions.
        // setup
        Current.date = { .t0 }
        let pkg = Package(url: "1")
        try pkg.save(on: app.db).wait()
        let old = try makeVersion(pkg, "sha_old", -26.hours, .branch("main"))
        let new0 = try makeVersion(pkg, "sha_new0", -3.hours, .branch("main"))
        let new1 = try makeVersion(pkg, "sha_new1", -2.hours, .branch("main"))
        let new2 = try makeVersion(pkg, "sha_new2", -1.hours, .branch("main"))

        // MUT
        let res = throttle(lastestExistingVersion: old,
                           incoming: [new0, new1, new2].shuffled())

        // validate
        XCTAssertEqual(res, [new2])
    }

    func test_diffVersions() throws {
        // Test that diffVersions applies throttling
        // setup
        var t: Date = .t0
        Current.date = { t }
        Current.git.getTags = { _ in [.branch("main")] }
        let pkg = Package(url: "1".asGithubUrl.url)
        try pkg.save(on: app.db).wait()
        let old = try makeVersion(pkg, "sha_old", -23.hours, .branch("main"))
        try old.save(on: app.db).wait()

        do {  // keep old version if too soon
            Current.git.revisionInfo = { _, _ in
                .init(commit: "sha_new", date: Date.t0.addingTimeInterval(-1.hours) )
            }

            // MUT
            let res = try diffVersions(client: app.client,
                                       logger: app.logger,
                                       threadPool: app.threadPool,
                                       transaction: app.db,
                                       package: pkg).wait()

            // validate
            XCTAssertEqual(res.toAdd, [])
            XCTAssertEqual(res.toDelete, [])
            XCTAssertEqual(res.toKeep, [old])
        }

        do {  // new version must come through
            t = t.addingTimeInterval(2.hours)

            Current.git.revisionInfo = { _, _ in
                // now simulate a newer branch revision
                .init(commit: "sha_new2", date: t )
            }

            // MUT
            let res = try diffVersions(client: app.client,
                                       logger: app.logger,
                                       threadPool: app.threadPool,
                                       transaction: app.db,
                                       package: pkg).wait()

            // validate
            XCTAssertEqual(res.toAdd.map(\.commit), ["sha_new2"])
            XCTAssertEqual(res.toDelete, [old])
            XCTAssertEqual(res.toKeep, [])
        }
    }

    func test_progression() throws {
        // Simulate progression through a time span of branch and tag updates
        // and checking the diffs are as expected.
        // Leaving tags out of it for simplicity - they are tested specifically
        // in test_throttle_ignore_tags above.

        // Little helper to simulate minimal version reconciliation
        func runVersionReconciliation() throws -> VersionDelta {
            let delta = try diffVersions(client: app.client,
                                         logger: app.logger,
                                         threadPool: app.threadPool,
                                         transaction: app.db,
                                         package: pkg).wait()
            // apply the delta to ensure versions are in place for next cycle
            try applyVersionDelta(on: app.db, delta: delta).wait()
            return delta
        }

        // setup
        let pkg = Package(url: "1".asGithubUrl.url)
        try pkg.save(on: app.db).wait()

        // start at t0
        var t = Date.t0
        Current.date = { t }

        do {  // start with a branch revision
            Current.git.getTags = { _ in [.branch("main")] }
            Current.git.revisionInfo = { _, _ in .init(commit: "sha0", date: t ) }

            let delta = try runVersionReconciliation()
            XCTAssertEqual(delta.toAdd.map(\.commit), ["sha0"])
            XCTAssertEqual(delta.toDelete, [])
            XCTAssertEqual(delta.toKeep, [])
        }

        do {  // one hour later a new commit landed - which should be ignored
            t = t.addingTimeInterval(1.hour)
            Current.git.getTags = { _ in [.branch("main")] }
            Current.git.revisionInfo = { _, _ in .init(commit: "sha1", date: t ) }

            let delta = try runVersionReconciliation()
            XCTAssertEqual(delta.toAdd, [])
            XCTAssertEqual(delta.toDelete, [])
            XCTAssertEqual(delta.toKeep.map(\.commit), ["sha0"])
        }

        do {  // run another 5 commits every four hours - they all should be ignored
            try (1...5).forEach { idx in
                t = t.addingTimeInterval(4.hours)
                Current.git.getTags = { _ in [.branch("main")] }
                Current.git.revisionInfo = { _, _ in .init(commit: "sha\(idx+1)", date: t ) }

                let delta = try runVersionReconciliation()
                XCTAssertEqual(delta.toAdd, [])
                XCTAssertEqual(delta.toDelete, [])
                XCTAssertEqual(delta.toKeep.map(\.commit), ["sha0"])
            }
        }

        do {  // advancing another 4 hours should finally create a new version
            t = t.addingTimeInterval(4.hours)
            Current.git.getTags = { _ in [.branch("main")] }
            Current.git.revisionInfo = { _, _ in .init(commit: "sha7", date: t ) }

            let delta = try runVersionReconciliation()
            XCTAssertEqual(delta.toAdd.map(\.commit), ["sha7"])
            XCTAssertEqual(delta.toDelete.map(\.commit), ["sha0"])
            XCTAssertEqual(delta.toKeep, [])
        }
    }

    func test_throttle_pathological_cases() throws {
        // Test the pathological case where we have a newer branch revision in
        // the db than the incoming version.
        // setup
        Current.date = { .t0 }
        let pkg = Package(url: "1")
        try pkg.save(on: app.db).wait()

        do {  // both within window
            let old = try makeVersion(pkg, "sha", -1.hours, .branch("main-old"))
            let new = try makeVersion(pkg, "sha", -23.hours, .branch("main-new"))

            // MUT
            let res = throttle(lastestExistingVersion: old, incoming: [new])

            // validate
            XCTAssertEqual(res, [old])
        }

        do {  // "new" version out of window
            let old = try makeVersion(pkg, "sha", -1.hours, .branch("main-old"))
            let new = try makeVersion(pkg, "sha", -26.hours, .branch("main-new"))

            // MUT
            let res = throttle(lastestExistingVersion: old, incoming: [new])

            // validate
            XCTAssertEqual(res, [old])
        }

        do {  // both versions out of window
            // FIXME: is this test correct?
            let old = try makeVersion(pkg, "sha", -26.hours, .branch("main-old"))
            let new = try makeVersion(pkg, "sha", -28.hours, .branch("main-new"))

            // MUT
            let res = throttle(lastestExistingVersion: old, incoming: [new])

            // validate
            XCTAssertEqual(res, [new])
            // XCTAsserEqual(res, [old]) ??
        }
    }

}


@discardableResult
private func makeVersion(_ package: Package,
                         _ commit: CommitHash,
                         _ commitDate: TimeInterval,
                         _ reference: Reference) throws -> Version {
    try Version(
        id: UUID(),
        package: package,
        commit: commit,
        commitDate: Date(timeIntervalSince1970: commitDate),
        reference: reference
    )
}


extension Version: CustomDebugStringConvertible {
    public var debugDescription: String {
        commit ?? "nil"
    }
}
