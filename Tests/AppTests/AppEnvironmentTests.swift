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

import Vapor
import XCTest


class AppEnvironmentTests: XCTestCase {

    func test_Filemanager_checkoutsDirectory() throws {
        Current.fileManager = .live
        unsetenv("CHECKOUTS_DIR")
        XCTAssertEqual(Current.fileManager.checkoutsDirectory(),
                       DirectoryConfiguration.detect().workingDirectory + "SPI-checkouts")
        setenv("CHECKOUTS_DIR", "/tmp/foo", 1)
        XCTAssertEqual(Current.fileManager.checkoutsDirectory(), "/tmp/foo")
    }

    func test_isValidAPIToken() throws {
        do {
            Current.apiTokens = { .init(arrayLiteral: "foo") }
            XCTAssertEqual(Current.isValidAPIToken("foo"), true)
            XCTAssertEqual(Current.isValidAPIToken("bar"), false)
            XCTAssertEqual(Current.isValidAPIToken("Foo"), false)
        }
        do {
            Current.apiTokens = { .init() }
            XCTAssertEqual(Current.isValidAPIToken("foo"), false)
        }
        do {
            Current.apiTokens = { .init(arrayLiteral: "foo", "bar") }
            XCTAssertEqual(Current.isValidAPIToken("foo"), true)
            XCTAssertEqual(Current.isValidAPIToken("bar"), true)
            XCTAssertEqual(Current.isValidAPIToken("baz"), false)
        }
    }

}
