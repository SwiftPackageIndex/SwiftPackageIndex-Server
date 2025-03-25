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

import Dependencies
import Testing


extension AllTests.AlertingTests {

    @Test func validatePlatformsPresent() throws {
        let all = Build.Platform.allCases.map {
            Alerting.BuildInfo.mock(platform: $0)
        }
        #expect(all.validatePlatformsPresent() == .ok)
        #expect(all.filter { $0.platform != .iOS }.validatePlatformsPresent() == .failed(reasons: ["Missing platform: ios"]))
        #expect(all.filter { $0.platform != .iOS && $0.platform != .linux }.validatePlatformsPresent() == .failed(reasons: ["Missing platform: ios", "Missing platform: linux"]))
    }

    @Test func validateSwiftVersionPresent() throws {
        let all = SwiftVersion.allActive.map {
            Alerting.BuildInfo.mock(swiftVersion: $0)
        }
        #expect(all.validateSwiftVersionsPresent() == .ok)
        #expect(all.filter { $0.swiftVersion != .v1 }.validateSwiftVersionsPresent() == .failed(reasons: ["Missing Swift version: 5.8"]))
        #expect(all.filter { $0.swiftVersion != .v1 && $0.swiftVersion != .v2 }.validateSwiftVersionsPresent() == .failed(reasons: ["Missing Swift version: 5.8", "Missing Swift version: 5.9"]))
    }

    @Test func validatePlatformsSuccessful() throws {
        let all = Build.Platform.allCases.map {
            Alerting.BuildInfo.mock(platform: $0, status: .ok)
        }
        #expect(all.validatePlatformsSuccessful() == .ok)
        #expect(all.filter { $0.platform != .iOS }.validatePlatformsSuccessful() == .failed(reasons: ["Platform without successful builds: ios"]))
        #expect(
            Array(all.filter { $0.platform != .iOS })
            .appending(.mock(platform: .iOS, status: .failed))
            .validatePlatformsSuccessful() == .failed(reasons: ["Platform without successful builds: ios"])
        )
        #expect(all.filter { $0.platform != .iOS && $0.platform != .linux }.validatePlatformsSuccessful() == .failed(reasons: ["Platform without successful builds: ios", "Platform without successful builds: linux"]))
    }

    @Test func validateSwiftVersionsSuccessful() throws {
        let all = SwiftVersion.allActive.map {
            Alerting.BuildInfo.mock(swiftVersion: $0, status: .ok)
        }
        #expect(all.validateSwiftVersionsSuccessful() == .ok)
        #expect(all.filter { $0.swiftVersion != .v1 }.validateSwiftVersionsSuccessful() == .failed(reasons: ["Swift version without successful builds: 5.8"]))
        #expect(
            Array(all.filter { $0.swiftVersion != .v1 })
                .appending(.mock(swiftVersion: .v1, status: .failed))
            .validateSwiftVersionsSuccessful() == .failed(reasons: ["Swift version without successful builds: 5.8"])
        )
        #expect(all.filter { $0.swiftVersion != .v1 && $0.swiftVersion != .v2 }.validateSwiftVersionsSuccessful() == .failed(reasons: ["Swift version without successful builds: 5.8", "Swift version without successful builds: 5.9"]))
    }

    @Test func validateRunnerIdsPresent() throws {
        let runnerIds = ["a", "b", "c"]
        withDependencies {
            $0.environment.runnerIds = { runnerIds }
        } operation: {
            let all = runnerIds.map {
                Alerting.BuildInfo.mock(runnerId: $0)
            }
            #expect(all.validateRunnerIdsPresent() == .ok)
            #expect(all.filter { $0.runnerId != "a" }.validateRunnerIdsPresent() == .failed(reasons: ["Missing runner id: a"]))
            #expect(all.filter { $0.runnerId != "a" && $0.runnerId != "b" }.validateRunnerIdsPresent() == .failed(reasons: ["Missing runner id: a", "Missing runner id: b"]))
        }
    }

    @Test func validateRunnerIdsSuccessful() throws {
        let runnerIds = ["a", "b", "c"]
        withDependencies {
            $0.environment.runnerIds = { runnerIds }
        } operation: {
            let all = runnerIds.map {
                Alerting.BuildInfo.mock(runnerId: $0, status: .ok)
            }
            #expect(all.validateRunnerIdsSuccessful() == .ok)
            #expect(all.filter { $0.runnerId != "a" }.validateRunnerIdsSuccessful() == .failed(reasons: ["Runner id without successful builds: a"]))
            #expect(
                Array(all.filter { $0.runnerId != "a" })
                    .appending(.mock(runnerId: "a", status: .failed))
                    .validateRunnerIdsSuccessful() == .failed(reasons: ["Runner id without successful builds: a"])
            )
            #expect(all.filter { $0.runnerId != "a" && $0.runnerId != "b" }.validateRunnerIdsSuccessful() == .failed(reasons: ["Runner id without successful builds: a", "Runner id without successful builds: b"]))
        }
    }

    @Test func validateSuccessRateInRange() throws {
        do {
            let okCount = 300
            let failedCount = 1000 - okCount
            let okBuilds = (0..<okCount).map { _ in Alerting.BuildInfo.mock(status: .ok) }
            let failedBuilds = (0..<failedCount).map { _ in Alerting.BuildInfo.mock(status: .failed) }
            let all = okBuilds + failedBuilds
            #expect(all.validateSuccessRateInRange() == .ok)
        }
        do {
            let okCount = 199
            let failedCount = 1000 - okCount
            let okBuilds = (0..<okCount).map { _ in Alerting.BuildInfo.mock(status: .ok) }
            let failedBuilds = (0..<failedCount).map { _ in Alerting.BuildInfo.mock(status: .failed) }
            let all = okBuilds + failedBuilds
            #expect(all.validateSuccessRateInRange() == .failed(reasons: ["Global success rate of 19.9% out of bounds"]))
        }
        do {
            let okCount = 401
            let failedCount = 1000 - okCount
            let okBuilds = (0..<okCount).map { _ in Alerting.BuildInfo.mock(status: .ok) }
            let failedBuilds = (0..<failedCount).map { _ in Alerting.BuildInfo.mock(status: .failed) }
            let all = okBuilds + failedBuilds
            #expect(all.validateSuccessRateInRange() == .failed(reasons: ["Global success rate of 40.1% out of bounds"]))
        }
    }

    @Test func Mon001Row_isValid() throws {
        #expect([Alerting.Mon001Row]().isValid() == .ok)
        #expect(
            [
                Alerting.Mon001Row(owner: "bar", repository: "2", status: .ok, processingStage: .analysis, updatedAt: .t1),
                Alerting.Mon001Row(owner: "foo", repository: "1", status: nil, processingStage: nil, updatedAt: .t0)
            ].isValid() == .failed(reasons: [
                "Outdated package: foo/1 - - 1970-01-01 00:00:00 +0000",
                "Outdated package: bar/2 ok analysis 1970-01-01 00:00:01 +0000"
            ])
        )
    }
}


extension Alerting.BuildInfo {
    static func mock(platform: Build.Platform = .iOS, runnerId: String? = nil, swiftVersion: SwiftVersion = .latest, status: Build.Status = .ok) -> Self {
        .init(createdAt: .t0, updatedAt: .t0, platform: platform, runnerId: runnerId, status: status, swiftVersion: swiftVersion)
    }
}


extension [Alerting.BuildInfo] {
    func appending(_ newElement: Element) -> Self {
        var array = self
        array.append(newElement)
        return array
    }
}
