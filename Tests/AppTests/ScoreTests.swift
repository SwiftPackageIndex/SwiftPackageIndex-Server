@testable import App

import XCTest


class ScoreTests: XCTestCase {

    func test_computeScore() throws {
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: false,
                                           licenseKind: .noneOrUnknown,
                                           releaseCount: 0,
                                           likeCount: 0)),
                       0)
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: false,
                                           licenseKind: .incompatibleWithAppStore,
                                           releaseCount: 0,
                                           likeCount: 0)),
                       3)
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: false,
                                           licenseKind: .compatibleWithAppStore,
                                           releaseCount: 0,
                                           likeCount: 0)),
                       10)
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: true,
                                           licenseKind: .compatibleWithAppStore,
                                           releaseCount: 0,
                                           likeCount: 0)),
                       20)
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: true,
                                           licenseKind: .compatibleWithAppStore,
                                           releaseCount: 10,
                                           likeCount: 0)),
                       30)
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: true,
                                           licenseKind: .compatibleWithAppStore,
                                           releaseCount: 10,
                                           likeCount: 50)),
                       40)
        // current maximum value
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: true,
                                           licenseKind: .compatibleWithAppStore,
                                           releaseCount: 20,
                                           likeCount: 20_000)),
                       77)
    }

}
