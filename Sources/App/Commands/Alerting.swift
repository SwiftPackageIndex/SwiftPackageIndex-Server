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

import Fluent
import SQLKit
import Vapor
import NIOCore


enum Alerting {
    struct Command: AsyncCommand {
        var help: String { "Application level alerting" }

        struct Signature: CommandSignature {
            @Option(name: "time-period", short: "t")
            var timePeriod: Int?

            @Option(name: "limit", short: "l")
            var limit: Int?

            static let defaultLimit = 2000
            static let defaultTimePeriod = 2

            var duration: TimeAmount {
                .hours(Int64(timePeriod ?? Self.defaultTimePeriod))
            }
        }

        func run(using context: CommandContext, signature: Signature) async throws {
            Current.setLogger(Logger(component: "alerting"))

            Current.logger().info("Running alerting...")

            let timePeriod = signature.duration
            let limit = signature.limit ?? Signature.defaultLimit

            Current.logger().info("Validation time interval: \(timePeriod.hours)h, limit: \(limit)")

            let builds = try await Alerting.fetchBuilds(on: context.application.db, timePeriod: timePeriod, limit: limit)
            try await Alerting.runChecks(for: builds)
        }
    }
}

extension Alerting {
    struct BuildInfo {
        var createdAt: Date
        var updatedAt: Date
        var builderVersion: String?
        var platform: Build.Platform
        var runnerId: String?
        var status: Build.Status
        var swiftVersion: SwiftVersion

        init(createdAt: Date, updatedAt: Date, builderVersion: String? = nil, platform: Build.Platform, runnerId: String? = nil, status: Build.Status, swiftVersion: SwiftVersion) {
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.builderVersion = builderVersion
            self.platform = platform
            self.runnerId = runnerId
            self.status = status
            self.swiftVersion = swiftVersion
        }

        init(_ build: Build) {
            self.createdAt = build.createdAt!
            self.updatedAt = build.updatedAt!
            self.builderVersion = build.builderVersion
            self.platform = build.platform
            self.runnerId = build.runnerId
            self.status = build.status
            self.swiftVersion = build.swiftVersion
        }
    }

    static func runChecks(for builds: [BuildInfo]) async throws {
        // alert if
        // - [x] there are no builds
        // - [x] there are no builds for a certain platform
        // - [x] there are no builds for a certain Swift version
        // - [x] there are no successful builds for a certain platform
        // - [x] there are no successful builds for a certain Swift version
        // - [x] there are no builds for a certain runnerId
        // - [x] there are no successful builds for a certain runnerId
        // - [ ] doc gen is configured but it failed
        // - [ ] the success ratio is not around 30%

        Current.logger().info("Build records selected: \(builds.count)")
        if let oldest = builds.last {
            Current.logger().info("Oldest selected: \(oldest.createdAt)")
        }
        if let mostRecent = builds.first {
            Current.logger().info("Most recent selected: \(mostRecent.createdAt)")
        }
        builds.validateBuildsPresent().log(check: "CHECK_BUILDS_PRESENT")
        builds.validatePlatformsPresent().log(check: "CHECK_BUILDS_PLATFORMS_PRESENT")
        builds.validateSwiftVersionsPresent().log(check: "CHECK_BUILDS_SWIFT_VERSIONS_PRESENT")
        builds.validatePlatformsSuccessful().log(check: "CHECK_BUILDS_PLATFORMS_SUCCESSFUL")
        builds.validateSwiftVersionsSuccessful().log(check: "CHECK_BUILDS_SWIFT_VERSIONS_SUCCESSFUL")
        builds.validateRunnerIdsPresent().log(check: "CHECK_BUILDS_RUNNER_IDS_PRESENT")
        builds.validateRunnerIdsSuccessful().log(check: "CHECK_BUILDS_RUNNER_IDS_SUCCESSFUL")
    }

    static func fetchBuilds(on database: Database, timePeriod: TimeAmount, limit: Int) async throws -> [Alerting.BuildInfo] {
        let start = Date.now
        defer {
            Current.logger().debug("fetchBuilds elapsed: \(Date.now.timeIntervalSince(start).rounded(decimalPlaces: 2))s")
        }
        let cutoff = Current.date().addingTimeInterval(-timePeriod.timeInterval)
        let builds = try await Build.query(on: database)
            .field(\.$createdAt)
            .field(\.$updatedAt)
            .field(\.$builderVersion)
            .field(\.$platform)
            .field(\.$runnerId)
            .field(\.$status)
            .field(\.$swiftVersion)
            .filter(Build.self, \.$createdAt >= cutoff)
            .sort(\.$createdAt, .descending)
            .limit(limit)
            .all()
            .map(BuildInfo.init)
        return builds
    }
}


extension Alerting {
    enum Validation: Equatable {
        case ok
        case failed(reasons: [String])

        func log(check: String) {
            switch self {
                case .ok:
                    Current.logger().debug("\(check) passed")
                case .failed(let reasons):
                    for reason in reasons {
                        Current.logger().critical("\(check) failed: \(reason)")
                    }
            }
        }
    }
}


extension [Alerting.BuildInfo] {
    func validateBuildsPresent() -> Alerting.Validation {
        isEmpty ? .failed(reasons: ["No builds"]) : .ok
    }

    func validatePlatformsPresent() -> Alerting.Validation {
        var notSeen = Set(Build.Platform.allCases)
        for build in self {
            notSeen.remove(build.platform)
            if notSeen.isEmpty { return .ok }
        }
        return .failed(reasons: notSeen.sorted().map { "Missing platform: \($0)" })
    }

    func validateSwiftVersionsPresent() -> Alerting.Validation {
        var notSeen = Set(SwiftVersion.allActive)
        for build in self {
            notSeen.remove(build.swiftVersion)
            if notSeen.isEmpty { return .ok }
        }
        return .failed(reasons: notSeen.sorted().map { "Missing Swift version: \($0)" })
    }

    func validatePlatformsSuccessful() -> Alerting.Validation {
        var noSuccess = Set(Build.Platform.allCases)
        for build in self where build.status == .ok {
            noSuccess.remove(build.platform)
            if noSuccess.isEmpty { return .ok }
        }
        return .failed(reasons: noSuccess.sorted().map { "Platform without successful builds: \($0)" })
    }

    func validateSwiftVersionsSuccessful() -> Alerting.Validation {
        var noSuccess = Set(SwiftVersion.allActive)
        for build in self where build.status == .ok {
            noSuccess.remove(build.swiftVersion)
            if noSuccess.isEmpty { return .ok }
        }
        return .failed(reasons: noSuccess.sorted().map { "Swift version without successful builds: \($0)" })
    }

    func validateRunnerIdsPresent() -> Alerting.Validation {
        var notSeen = Set(Current.runnerIds())
        for build in self where build.runnerId != nil {
            notSeen.remove(build.runnerId!)
            if notSeen.isEmpty { return .ok }
        }
        return .failed(reasons: notSeen.sorted().map { "Missing runner id: \($0)" })
    }

    func validateRunnerIdsSuccessful() -> Alerting.Validation {
        var noSuccess = Set(Current.runnerIds())
        for build in self where build.runnerId != nil && build.status == .ok {
            noSuccess.remove(build.runnerId!)
            if noSuccess.isEmpty { return .ok }
        }
        return .failed(reasons: noSuccess.sorted().map { "Runner id without successful builds: \($0)" })
    }
}


private extension TimeAmount {
    var timeInterval: TimeInterval {
        Double(nanoseconds) * 1e-9
    }
    var hours: Int {
        Int(timeInterval / 3600.0 + 0.5)
    }
}


private extension TimeInterval {
    func rounded(decimalPlaces: Int) -> Self {
        let scale = (pow(10, decimalPlaces) as NSDecimalNumber).doubleValue
        return (self * scale).rounded(.toNearestOrAwayFromZero) / scale
    }
}
