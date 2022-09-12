// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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

    func test_latestMajor() throws {
        XCTAssertEqual(SwiftVersion.latest.major, 5)
    }
    
}
