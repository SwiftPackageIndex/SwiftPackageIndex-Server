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
        Current.date = { .t0 }
        Current.fileManager.checkoutsDirectory = { "checkouts" }
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
            Current.git.revisionInfo = { _, _ in
                // now simulate a newer brnach revision
                .init(commit: "sha_new2", date: Date.t0.addingTimeInterval(1.hour) )
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
        throw XCTSkip("implement this properly")
        // Simulate a couple of days of processing
        // setup
        let pkg = Package(url: "1")
        try pkg.save(on: app.db).wait()

        // start at t0
        Current.date = { .t0 }
        let v0 = try makeVersion(pkg, "sha_0", 0.hours, .branch("main"))
        let deltas = Version.diff(local: [], incoming: [v0])
        XCTAssertEqual(deltas, .init(toAdd: [v0], toDelete: [], toKeep: []))

        // MUT
        //        let res = throttleBranchVersions(deltas, delay: 24.hours)

        // validate
        //        XCTAssertEqual(res.toAdd, [v0])
        //        XCTAssertEqual(res.toDelete, [])
        //        XCTAssertEqual(res.toKeep, [])
    }

    #warning("test same time/sha with name change")
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
