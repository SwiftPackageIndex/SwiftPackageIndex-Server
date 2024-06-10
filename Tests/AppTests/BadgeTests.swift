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

import XCTest


class BadgeTests: AppTestCase {

    func test_badgeMessage_swiftVersions() throws {
        XCTAssertEqual(Badge.badgeMessage(swiftVersions: [.v1, .v2, .v3, .v4]), "6.0 | 5.10 | 5.9 | 5.8")
        XCTAssertNil(Badge.badgeMessage(swiftVersions: []))
    }

    func test_badgeMessage_platforms() throws {
        XCTAssertEqual(Badge.badgeMessage(platforms: [.linux, .iOS, .macosXcodebuild, .macosSpm]),
                       "iOS | macOS | Linux")
        XCTAssertNil(Badge.badgeMessage(platforms: []))
    }

}
