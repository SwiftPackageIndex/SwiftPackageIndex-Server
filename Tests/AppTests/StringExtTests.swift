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
import XCTest
@testable import App

final class StringExtTests: XCTestCase {

    func test_pluralised() throws {
        XCTAssertEqual("version".pluralized(for: 0), "versions")
        XCTAssertEqual("version".pluralized(for: 1), "version")
        XCTAssertEqual("version".pluralized(for: 2), "versions")

        XCTAssertEqual("library".pluralized(for: 0, plural: "libraries"), "libraries")
        XCTAssertEqual("library".pluralized(for: 1, plural: "libraries"), "library")
        XCTAssertEqual("library".pluralized(for: 2, plural: "libraries"), "libraries")
    }

    func testDroppingGitSuffix() {
        XCTAssertEqual(
            "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server".droppingGitExtension,
            "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server"
        )

        XCTAssertEqual(
            "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server.git".droppingGitExtension,
            "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server"
        )
    }

    func testDroppingGitHubPrefix() {
        XCTAssertEqual(
            "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server".droppingGithubComPrefix,
            "SwiftPackageIndex/SwiftPackageIndex-Server"
        )
    }

    func testTrimming() {
        XCTAssertEqual("".trimmed, nil)
        XCTAssertEqual("  ".trimmed, nil)
        XCTAssertEqual(" string ".trimmed, "string")
        XCTAssertEqual("string".trimmed, "string")
    }
}
