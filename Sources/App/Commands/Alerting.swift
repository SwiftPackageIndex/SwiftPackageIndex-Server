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

            static let defaultTimePeriod = 2
            var duration: TimeAmount {
                .hours(Int64(timePeriod ?? Self.defaultTimePeriod))
            }
        }

        func run(using context: CommandContext, signature: Signature) async throws {
            Current.setLogger(Logger(component: "alerting"))

            Current.logger().info("Running alerting...")
            try await Alerting.runChecks(on: context.application.db, timePeriod: signature.duration)
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

    static func runChecks(on database: Database, timePeriod: TimeAmount) async throws {
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
            .limit(100)
            .all()
            .map(BuildInfo.init)

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

        Current.logger().info("Validation time interval: \(timePeriod.hours)h")
        builds.validateBuildsPresent().log(check: "CHECK_BUILDS_PRESENT")
        builds.validatePlatformsPresent().log(check: "CHECK_BUILDS_PLATFORMS_PRESENT")
        builds.validateSwiftVersionsPresent().log(check: "CHECK_BUILDS_SWIFT_VERSIONS_PRESENT")
        builds.validatePlatformsSuccessful().log(check: "CHECK_BUILDS_PLATFORMS_SUCCESSFUL")
        builds.validateSwiftVersionsSuccessful().log(check: "CHECK_BUILDS_SWIFT_VERSIONS_SUCCESSFUL")
        builds.validateRunnerIdsPresent().log(check: "CHECK_BUILDS_RUNNER_IDS_PRESENT")
        builds.validateRunnerIdsSuccessful().log(check: "CHECK_BUILDS_RUNNER_IDS_SUCCESSFUL")
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
        for build in self {
            if build.status == .ok {
                noSuccess.remove(build.platform)
            }
            if noSuccess.isEmpty { return .ok }
        }
        return .failed(reasons: noSuccess.sorted().map { "Platform without successful builds: \($0)" })
    }

    func validateSwiftVersionsSuccessful() -> Alerting.Validation {
        var noSuccess = Set(SwiftVersion.allActive)
        for build in self {
            if build.status == .ok {
                noSuccess.remove(build.swiftVersion)
            }
            if noSuccess.isEmpty { return .ok }
        }
        return .failed(reasons: noSuccess.sorted().map { "Swift version without successful builds: \($0)" })
    }

    func validateRunnerIdsPresent() -> Alerting.Validation {
        var notSeen = Set(Current.runnerIds())
        for build in self.filter({ $0.runnerId != nil }) {
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
