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


class VersionImmutableReferenceDiffTests: XCTestCase {
    // Tests different version diffing scenarios for lower level
    // [Version.ImmutableReference] interface.
    // Scenarios:
    // 1) branch changes commit hash
    // 2) new tag is added
    // 3) tag is removed
    // 4) branch is removed
    // 5) tag is moved

    func test_diff_1() throws {
        // Branch changes commit hash
        // setup
        let saved: [Version.ImmutableReference] = [
            .init(reference: .branch("main"), commit: "hash1"),
            .init(reference: .tag(1, 2, 3), commit: "hash2"),
        ]

        // MUT
        let res = Version.diff(local: saved, incoming: [
            .init(reference: .branch("main"), commit: "hash3"),
            .init(reference: .tag(1, 2, 3), commit: "hash2")
        ])

        // validate
        XCTAssertEqual(res.toAdd,
                       [.init(reference: .branch("main"), commit: "hash3")])
        XCTAssertEqual(res.toDelete,
                       [.init(reference: .branch("main"), commit: "hash1")])
        XCTAssertEqual(res.toKeep,
                       [.init(reference: .tag(1, 2, 3), commit: "hash2")])
    }

    func test_diff_2() throws {
        // New tag is incoming
        // setup
        let saved: [Version.ImmutableReference] = [
            .init(reference: .branch("main"), commit: "hash1"),
            .init(reference: .tag(1, 2, 3), commit: "hash2"),
        ]

        // MUT
        let res = Version.diff(local: saved, incoming: [
            .init(reference: .branch("main"), commit: "hash1"),
            .init(reference: .tag(1, 2, 3), commit: "hash2"),
            .init(reference: .tag(2, 0, 0), commit: "hash4"),
        ])

        // validate
        XCTAssertEqual(res.toAdd,
                       [.init(reference: .tag(2, 0, 0), commit: "hash4")])
        XCTAssertEqual(res.toDelete, [])
        XCTAssertEqual(res.toKeep,
                       [.init(reference: .branch("main"), commit: "hash1"),
                        .init(reference: .tag(1, 2, 3), commit: "hash2")])
    }

    func test_diff_3() throws {
        // Tag was deleted upstream
        // setup
        let saved: [Version.ImmutableReference] = [
            .init(reference: .branch("main"), commit: "hash1"),
            .init(reference: .tag(1, 2, 3), commit: "hash2"),
        ]

        // MUT
        let res = Version.diff(local: saved, incoming: [
            .init(reference: .branch("main"), commit: "hash1"),
        ])

        // validate
        XCTAssertEqual(res.toAdd, [])
        XCTAssertEqual(res.toDelete,
                       [.init(reference: .tag(1, 2, 3), commit: "hash2")])
        XCTAssertEqual(res.toKeep,
                       [.init(reference: .branch("main"), commit: "hash1")])
    }

    func test_diff_4() throws {
        // Branch was deleted upstream
        // setup
        let saved: [Version.ImmutableReference] = [
            .init(reference: .branch("main"), commit: "hash1"),
            .init(reference: .tag(1, 2, 3), commit: "hash2"),
        ]

        // MUT
        let res = Version.diff(local: saved, incoming: [
            .init(reference: .tag(1, 2, 3), commit: "hash2"),
        ])

        // validate
        XCTAssertEqual(res.toAdd, [])
        XCTAssertEqual(res.toDelete,
                       [.init(reference: .branch("main"), commit: "hash1")])
        XCTAssertEqual(res.toKeep,
                       [.init(reference: .tag(1, 2, 3), commit: "hash2")])
    }

    func test_diff_5() throws {
        // Tag was changed - retagging a release
        // setup
        let saved: [Version.ImmutableReference] = [
            .init(reference: .branch("main"), commit: "hash1"),
            .init(reference: .tag(1, 2, 3), commit: "hash2"),
        ]

        // MUT
        let res = Version.diff(local: saved, incoming: [
            .init(reference: .branch("main"), commit: "hash1"),
            .init(reference: .tag(1, 2, 3), commit: "hash3"),
        ])

        // validate
        XCTAssertEqual(res.toAdd, [.init(reference: .tag(1, 2, 3), commit: "hash3")])
        XCTAssertEqual(res.toDelete, [.init(reference: .tag(1, 2, 3), commit: "hash2")])
        XCTAssertEqual(res.toKeep,
                       [.init(reference: .branch("main"), commit: "hash1")])
    }

}


class VersionDiffTests: AppTestCase {
    // Test [Version] based diff (higher level interface)
    // Just run an integration scenario, the details are covered in the test above

    func test_diff_1() throws {
        // Branch changes commit hash
        // setup
        let pkg = try savePackage(on: app.db, "1")
        let keptId = UUID()
        let saved: [Version] = [
            try .init(package: pkg, commit: "hash1", reference: .branch("main")),
            try .init(id: keptId,
                      package: pkg, commit: "hash2", reference: .tag(1, 2, 3)),
        ]
        try saved.save(on: app.db).wait()

        // MUT
        let res = Version.diff(local: saved, incoming: [
            try .init(package: pkg, commit: "hash3", reference: .branch("main")),
            try .init(package: pkg, commit: "hash2", reference: .tag(1, 2, 3)),
            try .init(package: pkg, commit: "hash4", reference: .tag(2, 0, 0)),
        ])

        // validate
        XCTAssertEqual(res.toAdd.map(\.immutableReference),
                       [.init(reference: .branch("main"), commit: "hash3"),
                        .init(reference: .tag(2, 0, 0), commit: "hash4")])
        XCTAssertEqual(res.toDelete.map(\.immutableReference),
                       [.init(reference: .branch("main"), commit: "hash1")])
        XCTAssertEqual(res.toKeep.map(\.immutableReference),
                       [.init(reference: .tag(1, 2, 3), commit: "hash2")])
        XCTAssertEqual(res.toKeep.map(\.id), [keptId])
    }

}
