@testable import App

import XCTest


class ScoreTests: XCTestCase {

    func test_computeScore() throws {
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: false,
                                           hasAppStoreCompatibleLicense: false,
                                           releaseCount: 0,
                                           likeCount: 0)),
                       0)
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: true,
                                           hasAppStoreCompatibleLicense: false,
                                           releaseCount: 0,
                                           likeCount: 0)),
                       10)
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: true,
                                           hasAppStoreCompatibleLicense: false,
                                           releaseCount: 10,
                                           likeCount: 0)),
                       20)
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: true,
                                           hasAppStoreCompatibleLicense: false,
                                           releaseCount: 10,
                                           likeCount: 50)),
                       30)
        // current maximum value
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: true,
                                           hasAppStoreCompatibleLicense: true,
                                           releaseCount: 20,
                                           likeCount: 20_000)),
                       77)
    }

}
