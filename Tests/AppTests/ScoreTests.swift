@testable import App

import XCTest


class ScoreTests: XCTestCase {
    
    func test_computeScore() throws {
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: false,
                                           licenseKind: .none,
                                           releaseCount: 0,
                                           likeCount: 0,
                                           isArchived: false)),
                       0)
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: false,
                                           licenseKind: .incompatibleWithAppStore,
                                           releaseCount: 0,
                                           likeCount: 0,
                                           isArchived: false)),
                       3)
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: false,
                                           licenseKind: .compatibleWithAppStore,
                                           releaseCount: 0,
                                           likeCount: 0,
                                           isArchived: false)),
                       10)
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: true,
                                           licenseKind: .compatibleWithAppStore,
                                           releaseCount: 0,
                                           likeCount: 0,
                                           isArchived: false)),
                       20)
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: true,
                                           licenseKind: .compatibleWithAppStore,
                                           releaseCount: 10,
                                           likeCount: 0,
                                           isArchived: false)),
                       30)
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: true,
                                           licenseKind: .compatibleWithAppStore,
                                           releaseCount: 10,
                                           likeCount: 50,
                                           isArchived: false)),
                       40)
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: true,
                                           licenseKind: .compatibleWithAppStore,
                                           releaseCount: 10,
                                           likeCount: 50,
                                           isArchived: true)),
                       30)
        // current maximum value
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: true,
                                           licenseKind: .compatibleWithAppStore,
                                           releaseCount: 20,
                                           likeCount: 20_000,
                                           isArchived: false)),
                       77)
    }
    
}
