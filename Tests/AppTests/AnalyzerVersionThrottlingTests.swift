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

import Foundation

@testable import App

import Dependencies
import Testing


extension AllTests.AnalyzerVersionThrottlingTests {

    @Test func throttle_keep_old() async throws {
        // Test keeping old when within throttling window
        try await withApp { app in
            try await withDependencies {
                $0.date.now = .t0
            } operation: {
                // setup
                let pkg = Package(url: "1")
                try await pkg.save(on: app.db)
                let old = try makeVersion(pkg, "sha_old", -.hours(23), .branch("main"))
                let new = try makeVersion(pkg, "sha_new", -.hours(1), .branch("main"))

                // MUT
                let res = Analyze.throttle(latestExistingVersion: old, incoming: [new])

                // validate
                #expect(res == [old])
            }
        }
    }

    @Test func throttle_take_new() async throws {
        // Test picking new version when old one is outside the window
        try await withApp { app in
            try await withDependencies {
                $0.date.now = .t0
            } operation: {
                // setup
                let pkg = Package(url: "1")
                try await pkg.save(on: app.db)
                let old = try makeVersion(pkg, "sha_old", .hours(-26), .branch("main"))
                let new = try makeVersion(pkg, "sha_new", .hours(-1), .branch("main"))

                // MUT
                let res = Analyze.throttle(latestExistingVersion: old, incoming: [new])

                // validate
                #expect(res == [new])
            }
        }
    }

    @Test func throttle_ignore_tags() async throws {
        // Test to ensure tags are exempt from throttling
        try await withApp { app in
            try await withDependencies {
                $0.date.now = .t0
            } operation: {
                // setup
                let pkg = Package(url: "1")
                try await pkg.save(on: app.db)
                let old = try makeVersion(pkg, "sha_old", .hours(-23), .tag(1, 0, 0))
                let new = try makeVersion(pkg, "sha_new", .hours(-1), .tag(2, 0, 0))

                // MUT
                let res = Analyze.throttle(latestExistingVersion: old, incoming: [new])

                // validate
                #expect(res == [new])
            }
        }
    }

    @Test func throttle_new_package() async throws {
        // Test picking up a new package's branch
        try await withApp { app in
            try await withDependencies {
                $0.date.now = .t0
            } operation: {
                // setup
                let pkg = Package(url: "1")
                try await pkg.save(on: app.db)
                let new = try makeVersion(pkg, "sha_new", .hours(-1), .branch("main"))

                // MUT
                let res = Analyze.throttle(latestExistingVersion: nil, incoming: [new])

                // validate
                #expect(res == [new])
            }
        }
    }

    @Test func throttle_branch_ref_change() async throws {
        // Test behaviour when changing default branch names
        // Changed to return [new] to avoid branch renames causing 404s
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2217
        try await withApp { app in
            try await withDependencies {
                $0.date.now = .t0
            } operation: {
                // setup
                let pkg = Package(url: "1")
                try await pkg.save(on: app.db)
                let old = try makeVersion(pkg, "sha_old", .hours(-23), .branch("develop"))
                let new = try makeVersion(pkg, "sha_new", .hours(-1), .branch("main"))

                // MUT
                let res = Analyze.throttle(latestExistingVersion: old, incoming: [new])

                // validate
                #expect(res == [new])
            }
        }
    }

    @Test func throttle_rename() async throws {
        // Ensure incoming branch renames are throttled
        // Changed to return [new] to avoid branch renames causing 404s
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2217
        try await withApp { app in
            try await withDependencies {
                $0.date.now = .t0
            } operation: {
                // setup
                let pkg = Package(url: "1")
                try await pkg.save(on: app.db)
                let old = try makeVersion(pkg, "sha", .hours(-1), .branch("main-old"))
                let new = try makeVersion(pkg, "sha", .hours(-1), .branch("main-new"))

                // MUT
                let res = Analyze.throttle(latestExistingVersion: old, incoming: [new])

                // validate
                #expect(res == [new])
            }
        }
    }

    @Test func throttle_multiple_incoming_branches_keep_old() async throws {
        // Test behaviour with multiple incoming branch revisions
        // NB: this is a theoretical scenario, in practise there should only
        // ever be one branch revision among the incoming revisions.
        try await withApp { app in
            try await withDependencies {
                $0.date.now = .t0
            } operation: {
                // setup
                let pkg = Package(url: "1")
                try await pkg.save(on: app.db)
                let old = try makeVersion(pkg, "sha_old", .hours(-23), .branch("main"))
                let new0 = try makeVersion(pkg, "sha_new0", .hours(-3), .branch("main"))
                let new1 = try makeVersion(pkg, "sha_new1", .hours(-2), .branch("main"))
                let new2 = try makeVersion(pkg, "sha_new2", .hours(-1), .branch("main"))

                // MUT
                let res = Analyze.throttle(latestExistingVersion: old,
                                           incoming: [new0, new1, new2].shuffled())

                // validate
                #expect(res == [old])
            }
        }
    }

    @Test func throttle_multiple_incoming_branches_take_new() async throws {
        // Test behaviour with multiple incoming branch revisions
        // NB: this is a theoretical scenario, in practise there should only
        // ever be one branch revision among the incoming revisions.
        try await withApp { app in
            try await withDependencies {
                $0.date.now = .t0
            } operation: {
                // setup
                let pkg = Package(url: "1")
                try await pkg.save(on: app.db)
                let old = try makeVersion(pkg, "sha_old", .hours(-26), .branch("main"))
                let new0 = try makeVersion(pkg, "sha_new0", .hours(-3), .branch("main"))
                let new1 = try makeVersion(pkg, "sha_new1", .hours(-2), .branch("main"))
                let new2 = try makeVersion(pkg, "sha_new2", .hours(-1), .branch("main"))

                // MUT
                let res = Analyze.throttle(latestExistingVersion: old,
                                           incoming: [new0, new1, new2].shuffled())

                // validate
                #expect(res == [new2])
            }
        }
    }

    @Test func diffVersions() async throws {
        // Test that diffVersions applies throttling
        try await withApp { app in
            try await withDependencies {
                $0.date.now = .t0
                $0.git.getTags = { @Sendable _ in [.branch("main")] }
                $0.git.hasBranch = { @Sendable _, _ in true }
            } operation: {
                // setup
                let pkg = Package(url: "1".asGithubUrl.url)
                try await pkg.save(on: app.db)
                try await Repository(package: pkg, defaultBranch: "main").save(on: app.db)
                let old = try makeVersion(pkg, "sha_old", .hours(-23), .branch("main"), .defaultBranch)
                try await old.save(on: app.db)
                let jpr = try await Package.fetchCandidate(app.db, id: pkg.id!)

                try await withDependencies {  // keep old version if too soon
                    $0.git.revisionInfo = { @Sendable _, _ in
                            .init(commit: "sha_new", date: .t0.addingTimeInterval(.hours(-1)) )
                    }
                } operation: {
                    // MUT
                    let res = try await Analyze.diffVersions(client: app.client,
                                                             transaction: app.db,
                                                             package: jpr)

                    // validate
                    #expect(res.toAdd == [])
                    #expect(res.toDelete == [])
                    #expect(res.toKeep == [old])
                }

                try await withDependencies {
                    $0.date.now = .t0.addingTimeInterval(.hours(2))
                    // new version must come through
                    $0.git.revisionInfo = { @Sendable _, _ in
                        // now simulate a newer branch revision
                            .init(commit: "sha_new2", date: .t0.addingTimeInterval(.hours(2)) )
                    }
                } operation: {
                    // MUT
                    let res = try await Analyze.diffVersions(client: app.client,
                                                             transaction: app.db,
                                                             package: jpr)

                    // validate
                    #expect(res.toAdd.map(\.commit) == ["sha_new2"])
                    #expect(res.toDelete == [old])
                    #expect(res.toKeep == [])
                }
            }
        }
    }

    @Test func progression() async throws {
        // Simulate progression through a time span of branch and tag updates
        // and checking the diffs are as expected.
        try await withApp { app in
            try await withDependencies {
                // Leaving tags out of it for simplicity - they are tested specifically
                // in test_throttle_ignore_tags above.
                $0.git.getTags = { @Sendable _ in [] }
                $0.git.hasBranch = { @Sendable _, _ in true }
            } operation: {

                // Little helper to simulate minimal version reconciliation
                func runVersionReconciliation() async throws -> VersionDelta {
                    let delta = try await Analyze.diffVersions(client: app.client,
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
                let jpr = try await Package.fetchCandidate(app.db, id: pkg.id!)

                // start at t0
                let commitDates: [Date] = [
                    .t0,
                    .t0.addingTimeInterval(.hours(1)),
                    .t0.addingTimeInterval(.hours(5)),
                    .t0.addingTimeInterval(.hours(9)),
                    .t0.addingTimeInterval(.hours(13)),
                    .t0.addingTimeInterval(.hours(17)),
                    .t0.addingTimeInterval(.hours(21)),
                    .t0.addingTimeInterval(.hours(25)),
                ]

                try await withDependencies {
                    $0.date.now = commitDates[0]
                    // start with a branch revision
                    $0.git.revisionInfo = { @Sendable _, _ in .init(commit: "sha0", date: commitDates[0] ) }
                } operation: {
                    let delta = try await runVersionReconciliation()
                    #expect(delta.toAdd.map(\.commit) == ["sha0"])
                    #expect(delta.toDelete == [])
                    #expect(delta.toKeep == [])
                }

                try await withDependencies {
                    $0.date.now = commitDates[1]
                    // one hour later a new commit landed - which should be ignored
                    $0.git.revisionInfo = { @Sendable _, _ in .init(commit: "sha1", date: commitDates[1] ) }
                } operation: {
                    let delta = try await runVersionReconciliation()
                    #expect(delta.toAdd == [])
                    #expect(delta.toDelete == [])
                    #expect(delta.toKeep.map(\.commit) == ["sha0"])
                }

                // run another 5 commits every four hours - they all should be ignored
                for idx in 2...6 {
                    try await withDependencies {
                        $0.date.now = commitDates[idx]
                        $0.git.revisionInfo = { @Sendable _, _ in .init(commit: "sha\(idx)", date: commitDates[idx] ) }
                    } operation: {
                        let delta = try await runVersionReconciliation()
                        #expect(delta.toAdd == [])
                        #expect(delta.toDelete == [])
                        #expect(delta.toKeep.map(\.commit) == ["sha0"])
                    }
                }

                try await withDependencies {
                    $0.date.now = commitDates[7]
                    // advancing another 4 hours for a total of 25 hours should finally create a new version
                    $0.git.revisionInfo = { @Sendable _, _ in .init(commit: "sha7", date: commitDates[7] ) }
                } operation: {
                    let delta = try await runVersionReconciliation()
                    #expect(delta.toAdd.map(\.commit) == ["sha7"])
                    #expect(delta.toDelete.map(\.commit) == ["sha0"])
                    #expect(delta.toKeep == [])
                }
            }
        }
    }

    @Test func throttle_force_push() async throws {
        // Test the exceptional case where we have a newer branch revision in
        // the db than the incoming version. This could happen for instance
        // if an older branch revision is force pushed, effectively removing
        // the "existing" (ex) revision, replacing it with an older "incoming"
        // (inc) revision.
        // setup
        try await withApp { app in
            try await withDependencies {
                $0.date.now = .t0
            } operation: {
                let pkg = Package(url: "1")
                try await pkg.save(on: app.db)

                do {  // both within window
                    let ex = try makeVersion(pkg, "sha-ex", .hours(-1), .branch("main"))
                    let inc = try makeVersion(pkg, "sha-inc", .hours(-23), .branch("main"))

                    // MUT
                    let res = Analyze.throttle(latestExistingVersion: ex, incoming: [inc])

                    // validate
                    #expect(res == [ex])
                }

                do {  // incoming version out of window
                    let ex = try makeVersion(pkg, "sha-ex", .hours(-1), .branch("main"))
                    let inc = try makeVersion(pkg, "sha-inc", .hours(-26), .branch("main"))

                    // MUT
                    let res = Analyze.throttle(latestExistingVersion: ex, incoming: [inc])

                    // validate
                    #expect(res == [ex])
                }

                do {  // both versions out of window
                    let ex = try makeVersion(pkg, "sha-ex", .hours(-26), .branch("main"))
                    let inc = try makeVersion(pkg, "sha-inc", .hours(-28), .branch("main"))

                    // MUT
                    let res = Analyze.throttle(latestExistingVersion: ex, incoming: [inc])

                    // validate
                    #expect(res == [inc])
                }
            }
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


extension App.Version: Swift.CustomDebugStringConvertible {
    public var debugDescription: String { commit }
}
