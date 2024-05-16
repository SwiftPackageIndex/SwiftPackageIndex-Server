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


class AlertingTests: XCTestCase {

    func test_validatePlatformsPresent() throws {
        Current.date = { .t1 }
        let all = Build.Platform.allCases.map {
            Alerting.BuildInfo.mock(updatedAt: .t0, platform: $0)
        }
        XCTAssertEqual(all.validatePlatformsPresent(), .ok)
        XCTAssertEqual(all.filter { $0.platform != .iOS }.validatePlatformsPresent(),
                       .failed(reasons: ["Missing platform: ios"]))
        XCTAssertEqual(all.filter { $0.platform != .iOS && $0.platform != .linux }.validatePlatformsPresent(),
                       .failed(reasons: ["Missing platform: ios", "Missing platform: linux"]))
    }

    func test_validateSwiftVersionPresent() throws {
        Current.date = { .t1 }
        let all = SwiftVersion.allActive.map {
            Alerting.BuildInfo.mock(updatedAt: .t0, swiftVersion: $0)
        }
        XCTAssertEqual(all.validateSwiftVersionsPresent(), .ok)
        XCTAssertEqual(all.filter { $0.swiftVersion != .v1 }.validateSwiftVersionsPresent(),
                       .failed(reasons: ["Missing Swift version: 5.7"]))
        XCTAssertEqual(all.filter { $0.swiftVersion != .v1 && $0.swiftVersion != .v2 }.validateSwiftVersionsPresent(),
                       .failed(reasons: ["Missing Swift version: 5.7", "Missing Swift version: 5.8"]))
    }

}


extension Alerting.BuildInfo {
    static func mock(updatedAt: Date, platform: Build.Platform) -> Self {
        .init(createdAt: updatedAt, updatedAt: updatedAt, platform: platform, status: .ok, swiftVersion: .latest)
    }
    static func mock(updatedAt: Date, swiftVersion: SwiftVersion) -> Self {
        .init(createdAt: updatedAt, updatedAt: updatedAt, platform: .iOS, status: .ok, swiftVersion: swiftVersion)
    }
}
