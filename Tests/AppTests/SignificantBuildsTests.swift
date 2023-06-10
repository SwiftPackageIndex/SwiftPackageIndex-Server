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


class SignificantBuildsTests: XCTestCase {

    func test_swiftVersionCompatibility() throws {
        // setup
        let sb = SignificantBuilds(buildInfo: [
            (.v5_7, .linux, .ok),
            (.v2, .macosSpm, .ok),
            (.v1, .ios, .failed)
        ])

        // MUT
        let res = try XCTUnwrap(sb.swiftVersionCompatibility().values)

        // validate
        XCTAssertEqual(res.sorted(), [.v2, .v5_7])
    }

    func test_swiftVersionCompatibility_allPending() throws {
        // setup
        let sb = SignificantBuilds(buildInfo: [
            (.v5_7, .linux, .triggered),
            (.v2, .macosSpm, .triggered),
            (.v1, .ios, .triggered)
        ])

        // MUT
        let res = sb.swiftVersionCompatibility()

        // validate
        XCTAssertEqual(res, .pending)
    }

    func test_swiftVersionCompatibility_partialPending() throws {
        // setup
        let sb = SignificantBuilds(buildInfo: [
            (.v5_7, .linux, .ok),
            (.v2, .macosSpm, .failed),
            (.v1, .ios, .triggered)
        ])

        // MUT
        let res = try XCTUnwrap(sb.swiftVersionCompatibility().values)

        // validate
        XCTAssertEqual(res.sorted(), [ .v5_7 ])
    }

    func test_platformCompatibility() throws {
        // setup
        let sb = SignificantBuilds(buildInfo: [
            (.v5_7, .linux, .ok),
            (.v2, .macosSpm, .ok),
            (.v1, .ios, .failed)
        ])

        // MUT
        let res = try XCTUnwrap(sb.platformCompatibility().values)

        // validate
        XCTAssertEqual(res.sorted(), [.macosSpm, .linux])
    }

    func test_platformCompatibility_allPending() throws {
        // setup
        let sb = SignificantBuilds(buildInfo: [
            (.v5_7, .linux, .triggered),
            (.v2, .macosSpm, .triggered),
            (.v1, .ios, .triggered)
        ])

        // MUT
        let res = sb.platformCompatibility()

        // validate
        XCTAssertEqual(res, .pending)
    }

    func test_platformCompatibility_partialPending() throws {
        // setup
        let sb = SignificantBuilds(buildInfo: [
            (.v5_7, .linux, .ok),
            (.v2, .macosSpm, .failed),
            (.v1, .ios, .triggered)
        ])

        // MUT
        let res = try XCTUnwrap(sb.platformCompatibility().values)

        // validate
        XCTAssertEqual(res.sorted(), [ .linux ])
    }

}


extension SignificantBuilds.BuildInfo: Comparable {
    public static func < (lhs: SignificantBuilds.BuildInfo, rhs: SignificantBuilds.BuildInfo) -> Bool {
        if lhs.swiftVersion != rhs.swiftVersion {
            return lhs.swiftVersion < rhs.swiftVersion
        }
        if lhs.platform != rhs.platform {
            return lhs.platform < rhs.platform
        }
        return lhs.status.rawValue < rhs.status.rawValue
    }
}
