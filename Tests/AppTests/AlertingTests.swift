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

    func test_checkBuildsMissingPlatform() throws {
        Current.date = { .t1 }
        let allBuilds = Build.Platform.allCases.map {
            Alerting.BuildInfo.mock(updatedAt: .t0, platform: $0)
        }
        XCTAssertEqual(allBuilds.validatePlatforms(period: .hours(1)), .ok)
        XCTAssertEqual(allBuilds.filter { $0.platform != .iOS }.validatePlatforms(period: .hours(1)),
                       .failed(reasons: ["Missing platform: ios"]))
        XCTAssertEqual(allBuilds.filter { $0.platform != .iOS && $0.platform != .linux }.validatePlatforms(period: .hours(1)),
                       .failed(reasons: ["Missing platform: ios", "Missing platform: linux"]))
    }

}


extension Alerting.BuildInfo {
    static func mock(updatedAt: Date, platform: Build.Platform) -> Self {
        .init(createdAt: updatedAt, updatedAt: updatedAt, platform: platform, status: .ok, swiftVersion: .latest)
    }
}
