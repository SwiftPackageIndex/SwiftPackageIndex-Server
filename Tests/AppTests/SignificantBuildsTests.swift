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

import Testing


extension AllTests.SignificantBuildsTests {

    @Test func swiftVersionCompatibility() throws {
        // setup
        let sb = SignificantBuilds(buildInfo: [
            (.v3, .linux, .ok),
            (.v2, .macosSpm, .ok),
            (.v1, .iOS, .failed)
        ])

        // MUT
        let res = try #require(sb.swiftVersionCompatibility().values)

        // validate
        #expect(res.sorted() == [.v2, .v3])
    }

    @Test func swiftVersionCompatibility_allPending() throws {
        // setup
        let sb = SignificantBuilds(buildInfo: [
            (.v3, .linux, .triggered),
            (.v2, .macosSpm, .triggered),
            (.v1, .iOS, .triggered)
        ])

        // MUT
        let res = sb.swiftVersionCompatibility()

        // validate
        #expect(res == .pending)
    }

    @Test func swiftVersionCompatibility_partialPending() throws {
        // setup
        let sb = SignificantBuilds(buildInfo: [
            (.v3, .linux, .ok),
            (.v2, .macosSpm, .failed),
            (.v1, .iOS, .triggered)
        ])

        // MUT
        let res = try #require(sb.swiftVersionCompatibility().values)

        // validate
        #expect(res.sorted() == [ .v3 ])
    }

    @Test func platformCompatibility() throws {
        // setup
        let sb = SignificantBuilds(buildInfo: [
            (.v3, .linux, .ok),
            (.v2, .macosSpm, .ok),
            (.v1, .iOS, .failed)
        ])

        // MUT
        let res = try #require(sb.platformCompatibility().values)

        // validate
        #expect(res.sorted() == [.macosSpm, .linux])
    }

    @Test func platformCompatibility_allPending() throws {
        // setup
        let sb = SignificantBuilds(buildInfo: [
            (.v3, .linux, .triggered),
            (.v2, .macosSpm, .triggered),
            (.v1, .iOS, .triggered)
        ])

        // MUT
        let res = sb.platformCompatibility()

        // validate
        #expect(res == .pending)
    }

    @Test func platformCompatibility_partialPending() throws {
        // setup
        let sb = SignificantBuilds(buildInfo: [
            (.v3, .linux, .ok),
            (.v2, .macosSpm, .failed),
            (.v1, .iOS, .triggered)
        ])

        // MUT
        let res = try #require(sb.platformCompatibility().values)

        // validate
        #expect(res.sorted() == [ .linux ])
    }

}


extension App.SignificantBuilds.BuildInfo: Swift.Comparable {
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
