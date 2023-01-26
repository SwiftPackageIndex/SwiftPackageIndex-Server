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

import XCTest

@testable import App


final class IntExtTests: XCTestCase {

    func test_pluralizedCount() throws {
        XCTAssertEqual(0.labeled("executable"), "no executables")
        XCTAssertEqual(1.labeled("executable"), "1 executable")
        XCTAssertEqual(2.labeled("executable"), "2 executables")

        XCTAssertEqual(1.labeled("library", plural: "libraries"), "1 library")
        XCTAssertEqual(2.labeled("library", plural: "libraries"), "2 libraries")

        XCTAssertEqual(0.labeled("executable", capitalized: true), "No executables")
        XCTAssertEqual(0.labeled("library", plural: "libraries", capitalized: true), "No libraries")
    }

}
