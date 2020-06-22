@testable import App

import XCTest


class VersionDiffTests: XCTestCase {
    // Tests different version diffing scenarios:
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
            .init(reference: .tag(.init(1, 2, 3)), commit: "hash2"),
        ]

        // MUT
        let res = Version.diff(local: saved, incoming: [
            .init(reference: .branch("main"), commit: "hash3"),
            .init(reference: .tag(.init(1, 2, 3)), commit: "hash2")
        ])

        // validate
        XCTAssertEqual(res.toAdd, [.init(reference: .branch("main"), commit: "hash3")])
        XCTAssertEqual(res.toDelete, [.init(reference: .branch("main"), commit: "hash1")])
    }

    func test_diff_2() throws {
        // New tag is incoming
        // setup
        let saved: [Version.ImmutableReference] = [
            .init(reference: .branch("main"), commit: "hash1"),
            .init(reference: .tag(.init(1, 2, 3)), commit: "hash2"),
        ]

        // MUT
        let res = Version.diff(local: saved, incoming: [
            .init(reference: .branch("main"), commit: "hash1"),
            .init(reference: .tag(.init(1, 2, 3)), commit: "hash2"),
            .init(reference: .tag(.init(2, 0, 0)), commit: "hash4"),
        ])

        // validate
        XCTAssertEqual(res.toAdd, [.init(reference: .tag(.init(2, 0, 0)), commit: "hash4")])
        XCTAssertEqual(res.toDelete, [])
    }

    func test_diff_3() throws {
        // Tag was deleted upstream
        // setup
        let saved: [Version.ImmutableReference] = [
            .init(reference: .branch("main"), commit: "hash1"),
            .init(reference: .tag(.init(1, 2, 3)), commit: "hash2"),
        ]

        // MUT
        let res = Version.diff(local: saved, incoming: [
            .init(reference: .branch("main"), commit: "hash1"),
        ])

        // validate
        XCTAssertEqual(res.toAdd, [])
        XCTAssertEqual(res.toDelete, [.init(reference: .tag(.init(1, 2, 3)), commit: "hash2")])
    }

    func test_diff_4() throws {
        // Branch was deleted upstream
        // setup
        let saved: [Version.ImmutableReference] = [
            .init(reference: .branch("main"), commit: "hash1"),
            .init(reference: .tag(.init(1, 2, 3)), commit: "hash2"),
        ]

        // MUT
        let res = Version.diff(local: saved, incoming: [
            .init(reference: .tag(.init(1, 2, 3)), commit: "hash2"),
        ])

        // validate
        XCTAssertEqual(res.toAdd, [])
        XCTAssertEqual(res.toDelete, [.init(reference: .branch("main"), commit: "hash1")])
    }

    func test_diff_5() throws {
        // Tag was changed - retagging a release
        // setup
        let saved: [Version.ImmutableReference] = [
            .init(reference: .branch("main"), commit: "hash1"),
            .init(reference: .tag(.init(1, 2, 3)), commit: "hash2"),
        ]

        // MUT
        let res = Version.diff(local: saved, incoming: [
            .init(reference: .branch("main"), commit: "hash1"),
            .init(reference: .tag(.init(1, 2, 3)), commit: "hash3"),
        ])

        // validate
        XCTAssertEqual(res.toAdd, [.init(reference: .tag(.init(1, 2, 3)), commit: "hash3")])
        XCTAssertEqual(res.toDelete, [.init(reference: .tag(.init(1, 2, 3)), commit: "hash2")])
    }

}
