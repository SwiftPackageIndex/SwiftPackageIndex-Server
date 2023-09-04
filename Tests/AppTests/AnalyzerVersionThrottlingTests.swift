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

import XCTest


class AnalyzerVersionThrottlingTests: AppTestCase {

    func test_throttle_keep_old() throws {
        // Test keeping old when within throttling window
        // setup
        Current.date = { .t0 }
        let pkg = Package(url: "1")
        try pkg.save(on: app.db).wait()
        let old = try makeVersion(pkg, "sha_old", -.hours(23), .branch("main"))
        let new = try makeVersion(pkg, "sha_new", -.hours(1), .branch("main"))

        // MUT
        let res = Analyze.throttle(latestExistingVersion: old, incoming: [new])

        // validate
        XCTAssertEqual(res, [old])
    }

    func test_throttle_take_new() throws {
        // Test picking new version when old one is outside the window
        // setup
        Current.date = { .t0 }
        let pkg = Package(url: "1")
        try pkg.save(on: app.db).wait()
        let old = try makeVersion(pkg, "sha_old", .hours(-26), .branch("main"))
        let new = try makeVersion(pkg, "sha_new", .hours(-1), .branch("main"))

        // MUT
        let res = Analyze.throttle(latestExistingVersion: old, incoming: [new])

        // validate
        XCTAssertEqual(res, [new])
    }

    func test_throttle_ignore_tags() throws {
        // Test to ensure tags are exempt from throttling
        // setup
        Current.date = { .t0 }
        let pkg = Package(url: "1")
        try pkg.save(on: app.db).wait()
        let old = try makeVersion(pkg, "sha_old", .hours(-23), .tag(1, 0, 0))
        let new = try makeVersion(pkg, "sha_new", .hours(-1), .tag(2, 0, 0))

        // MUT
        let res = Analyze.throttle(latestExistingVersion: old, incoming: [new])

        // validate
        XCTAssertEqual(res, [new])
    }

    func test_throttle_new_package() throws {
        // Test picking up a new package's branch
        // setup
        Current.date = { .t0 }
        let pkg = Package(url: "1")
        try pkg.save(on: app.db).wait()
        let new = try makeVersion(pkg, "sha_new", .hours(-1), .branch("main"))

        // MUT
        let res = Analyze.throttle(latestExistingVersion: nil, incoming: [new])

        // validate
        XCTAssertEqual(res, [new])
    }

    func test_throttle_branch_ref_change() throws {
        // Test behaviour when changing default branch names
        // Changed to return [new] to avoid branch renames causing 404s
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2217
        // setup
        Current.date = { .t0 }
        let pkg = Package(url: "1")
        try pkg.save(on: app.db).wait()
        let old = try makeVersion(pkg, "sha_old", .hours(-23), .branch("develop"))
        let new = try makeVersion(pkg, "sha_new", .hours(-1), .branch("main"))

        // MUT
        let res = Analyze.throttle(latestExistingVersion: old, incoming: [new])

        // validate
        XCTAssertEqual(res, [new])
    }

    func test_throttle_rename() throws {
        // Ensure incoming branch renames are throttled
        // Changed to return [new] to avoid branch renames causing 404s
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2217
        // setup
        Current.date = { .t0 }
        let pkg = Package(url: "1")
        try pkg.save(on: app.db).wait()
        let old = try makeVersion(pkg, "sha", .hours(-1), .branch("main-old"))
        let new = try makeVersion(pkg, "sha", .hours(-1), .branch("main-new"))

        // MUT
        let res = Analyze.throttle(latestExistingVersion: old, incoming: [new])

        // validate
        XCTAssertEqual(res, [new])
    }

    func test_throttle_multiple_incoming_branches_keep_old() throws {
        // Test behaviour with multiple incoming branch revisions
        // NB: this is a theoretical scenario, in practise there should only
        // ever be one branch revision among the incoming revisions.
        // setup
        Current.date = { .t0 }
        let pkg = Package(url: "1")
        try pkg.save(on: app.db).wait()
        let old = try makeVersion(pkg, "sha_old", .hours(-23), .branch("main"))
        let new0 = try makeVersion(pkg, "sha_new0", .hours(-3), .branch("main"))
        let new1 = try makeVersion(pkg, "sha_new1", .hours(-2), .branch("main"))
        let new2 = try makeVersion(pkg, "sha_new2", .hours(-1), .branch("main"))

        // MUT
        let res = Analyze.throttle(latestExistingVersion: old,
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
        let old = try makeVersion(pkg, "sha_old", .hours(-26), .branch("main"))
        let new0 = try makeVersion(pkg, "sha_new0", .hours(-3), .branch("main"))
        let new1 = try makeVersion(pkg, "sha_new1", .hours(-2), .branch("main"))
        let new2 = try makeVersion(pkg, "sha_new2", .hours(-1), .branch("main"))

        // MUT
        let res = Analyze.throttle(latestExistingVersion: old,
                                   incoming: [new0, new1, new2].shuffled())

        // validate
        XCTAssertEqual(res, [new2])
    }

    func test_diffVersions() async throws {
        // Test that diffVersions applies throttling
        // setup
        var t: Date = .t0
        Current.date = { t }
        Current.git.getTags = { _ in [.branch("main")] }
        let pkg = Package(url: "1".asGithubUrl.url)
        try await pkg.save(on: app.db)
        try await Repository(package: pkg, defaultBranch: "main").save(on: app.db)
        let old = try makeVersion(pkg, "sha_old", .hours(-23), .branch("main"), .defaultBranch)
        try await old.save(on: app.db)
        let jpr = try await Package.fetchCandidate(app.db, id: pkg.id!).get()

        do {  // keep old version if too soon
            Current.git.revisionInfo = { _, _ in
                .init(commit: "sha_new", date: Date.t0.addingTimeInterval(.hours(-1)) )
            }

            // MUT
            let res = try await Analyze.diffVersions(client: app.client,
                                                     logger: app.logger,
                                                     transaction: app.db,
                                                     package: jpr)

            // validate
            XCTAssertEqual(res.toAdd, [])
            XCTAssertEqual(res.toDelete, [])
            XCTAssertEqual(res.toKeep, [old])
        }

        do {  // new version must come through
            t = t.addingTimeInterval(.hours(2))

            Current.git.revisionInfo = { _, _ in
                // now simulate a newer branch revision
                .init(commit: "sha_new2", date: t )
            }

            // MUT
            let res = try await Analyze.diffVersions(client: app.client,
                                                     logger: app.logger,
                                                     transaction: app.db,
                                                     package: jpr)

            // validate
            XCTAssertEqual(res.toAdd.map(\.commit), ["sha_new2"])
            XCTAssertEqual(res.toDelete, [old])
            XCTAssertEqual(res.toKeep, [])
        }
    }

    func test_progression() async throws {
        // Simulate progression through a time span of branch and tag updates
        // and checking the diffs are as expected.
        // Leaving tags out of it for simplicity - they are tested specifically
        // in test_throttle_ignore_tags above.
        Current.git.getTags = { _ in [] }

        // Little helper to simulate minimal version reconciliation
        func runVersionReconciliation() async throws -> VersionDelta {
            let delta = try await Analyze.diffVersions(client: app.client,
                                                       logger: app.logger,
                                                       transaction: app.db,
                                                       package: jpr)
            // apply the delta to ensure versions are in place for next cycle
            try await Analyze.applyVersionDelta(on: app.db, delta: delta)
            return delta
        }

        // setup
        let pkg = Package(url: "1".asGithubUrl.url)
        try await pkg.save(on: app.db)
        try await Repository(package: pkg, defaultBranch: "main").save(on: app.db)
        let jpr = try await Package.fetchCandidate(app.db, id: pkg.id!).get()

        // start at t0
        var t = Date.t0
        Current.date = { t }

        do {  // start with a branch revision
            Current.git.revisionInfo = { _, _ in .init(commit: "sha0", date: t ) }

            let delta = try await runVersionReconciliation()
            XCTAssertEqual(delta.toAdd.map(\.commit), ["sha0"])
            XCTAssertEqual(delta.toDelete, [])
            XCTAssertEqual(delta.toKeep, [])
        }

        do {  // one hour later a new commit landed - which should be ignored
            t = t.addingTimeInterval(.hours(1))
            Current.git.revisionInfo = { _, _ in .init(commit: "sha1", date: t ) }

            let delta = try await runVersionReconciliation()
            XCTAssertEqual(delta.toAdd, [])
            XCTAssertEqual(delta.toDelete, [])
            XCTAssertEqual(delta.toKeep.map(\.commit), ["sha0"])
        }

        do {  // run another 5 commits every four hours - they all should be ignored
            for idx in 1...5 {
                t = t.addingTimeInterval(.hours(4))
                Current.git.revisionInfo = { _, _ in .init(commit: "sha\(idx+1)", date: t ) }

                let delta = try await runVersionReconciliation()
                XCTAssertEqual(delta.toAdd, [])
                XCTAssertEqual(delta.toDelete, [])
                XCTAssertEqual(delta.toKeep.map(\.commit), ["sha0"])
            }
        }

        do {  // advancing another 4 hours should finally create a new version
            t = t.addingTimeInterval(.hours(4))
            Current.git.revisionInfo = { _, _ in .init(commit: "sha7", date: t ) }

            let delta = try await runVersionReconciliation()
            XCTAssertEqual(delta.toAdd.map(\.commit), ["sha7"])
            XCTAssertEqual(delta.toDelete.map(\.commit), ["sha0"])
            XCTAssertEqual(delta.toKeep, [])
        }
    }

    func test_throttle_force_push() throws {
        // Test the exceptional case where we have a newer branch revision in
        // the db than the incoming version. This could happen for instance
        // if an older branch revision is force pushed, effectively removing
        // the "existing" (ex) revision, replacing it with an older "incoming"
        // (inc) revision.
        // setup
        Current.date = { .t0 }
        let pkg = Package(url: "1")
        try pkg.save(on: app.db).wait()

        do {  // both within window
            let ex = try makeVersion(pkg, "sha-ex", .hours(-1), .branch("main"))
            let inc = try makeVersion(pkg, "sha-inc", .hours(-23), .branch("main"))

            // MUT
            let res = Analyze.throttle(latestExistingVersion: ex, incoming: [inc])

            // validate
            XCTAssertEqual(res, [ex])
        }

        do {  // incoming version out of window
            let ex = try makeVersion(pkg, "sha-ex", .hours(-1), .branch("main"))
            let inc = try makeVersion(pkg, "sha-inc", .hours(-26), .branch("main"))

            // MUT
            let res = Analyze.throttle(latestExistingVersion: ex, incoming: [inc])

            // validate
            XCTAssertEqual(res, [ex])
        }

        do {  // both versions out of window
            let ex = try makeVersion(pkg, "sha-ex", .hours(-26), .branch("main"))
            let inc = try makeVersion(pkg, "sha-inc", .hours(-28), .branch("main"))

            // MUT
            let res = Analyze.throttle(latestExistingVersion: ex, incoming: [inc])

            // validate
            XCTAssertEqual(res, [inc])
        }
    }

}


@discardableResult
private func makeVersion(_ package: Package,
                         _ commit: CommitHash,
                         _ commitDate: TimeInterval,
                         _ reference: Reference,
                         _ latest: Version.Kind? = nil) throws -> Version {
    try Version(
        id: UUID(),
        package: package,
        commit: commit,
        commitDate: Date(timeIntervalSince1970: commitDate),
        latest: latest,
        reference: reference
    )
}


extension Version: CustomDebugStringConvertible {
    public var debugDescription: String { commit }
}
