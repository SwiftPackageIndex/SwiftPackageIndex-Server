@testable import App

import XCTest


class SwiftVersionTests: XCTestCase {

    func test_swiftVerRegex() throws {
        XCTAssert(swiftVerRegex.matches("1"))
        XCTAssert(swiftVerRegex.matches("1.2"))
        XCTAssert(swiftVerRegex.matches("1.2.3"))
        XCTAssert(swiftVerRegex.matches("v1"))
        XCTAssertFalse(swiftVerRegex.matches("1."))
        XCTAssertFalse(swiftVerRegex.matches("1.2."))
        XCTAssertFalse(swiftVerRegex.matches("1.2.3-pre"))
    }

    func test_init() throws {
        XCTAssertEqual(SwiftVersion("5"), SwiftVersion(5, 0, 0))
        XCTAssertEqual(SwiftVersion("5.2"), SwiftVersion(5, 2, 0))
        XCTAssertEqual(SwiftVersion("5.2.1"), SwiftVersion(5, 2, 1))
        XCTAssertEqual(SwiftVersion("v5"), SwiftVersion(5, 0, 0))
    }

    func test_Comparable() throws {
        XCTAssertTrue(SwiftVersion("5")! < SwiftVersion("5.1")!)
        XCTAssertFalse(SwiftVersion("5")! < SwiftVersion("5.0")!)
        XCTAssertFalse(SwiftVersion("5")! > SwiftVersion("5.0")!)
        XCTAssertTrue(SwiftVersion("4.2")! < SwiftVersion("5")!)
    }
    
    func test_isCompatible() throws {
        let v4_2 = SwiftVersion(4, 2, 0)
        XCTAssertTrue(v4_2.isCompatible(with: .init(4, 2, 0)))
        XCTAssertTrue(v4_2.isCompatible(with: .init(4, 2, 4)))
        XCTAssertFalse(v4_2.isCompatible(with: .init(4, 0, 0)))
        XCTAssertFalse(v4_2.isCompatible(with: .init(5, 0, 0)))
    }

}
