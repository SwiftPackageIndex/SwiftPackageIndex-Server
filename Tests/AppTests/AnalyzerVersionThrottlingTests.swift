@testable import App

import XCTest


class AnalyzerVersionThrottlingTests: AppTestCase {

    func test_throttle_keep_old() throws {
        // Test keeping old when within throttling window
        // setup
        Current.date = { Date(timeIntervalSince1970: 0.hours) }
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
        Current.date = { Date(timeIntervalSince1970: 0.hours) }
        let pkg = Package(url: "1")
        try pkg.save(on: app.db).wait()
        let old = try makeVersion(pkg, "sha_old", -26.hours, .branch("main"))
        let new = try makeVersion(pkg, "sha_new", -1.hours, .branch("main"))

        // MUT
        let res = throttle(lastestExistingVersion: old, incoming: [new])

        // validate
        XCTAssertEqual(res, [new])
    }

    func test_throttleBranchVersions_advance() throws {
        throw XCTSkip("implement this properly")
        // Simulate a couple of days of processing
        // setup
        let pkg = Package(url: "1")
        try pkg.save(on: app.db).wait()

        // start at t0
        Current.date = { Date(timeIntervalSince1970: 0.hours) }
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

    #warning("add test to ensure we don't touch tags")
    #warning("test new package which has no existing .branch version")
    #warning("test branch ref change")

}


private func makeVersion(_ package: Package,
                         _ commit: CommitHash,
                         _ commitDate: TimeInterval,
                         _ reference: Reference) throws -> Version {
    try Version(
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
