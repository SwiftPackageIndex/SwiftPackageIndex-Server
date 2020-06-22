@testable import App

import XCTest


class VersionDiffTests: XCTestCase {

    func test_diff() throws {
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

}
