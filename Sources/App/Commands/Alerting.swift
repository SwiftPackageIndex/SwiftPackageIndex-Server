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

import Dependencies
import Fluent
import NIOCore
import SQLKit
import Vapor


enum Alerting {
    static let defaultLimit = 2000
    static let defaultTimePeriod = 2
    // CHECK_MON_001 has to run on a longer time period, because it currently takes ~4h to visit every package
    // during analysis. With a window shorter than that, they query will always report errors.
    static let checkMon001TimePeriod: TimeAmount = .hours(6)

    struct Command: AsyncCommand {
        var help: String { "Application level alerting" }

        struct Signature: CommandSignature {
            @Option(name: "time-period", short: "t")
            var timePeriod: Int?

            @Option(name: "limit", short: "l")
            var limit: Int?

            var duration: TimeAmount {
                .hours(Int64(timePeriod ?? Alerting.defaultTimePeriod))
            }
        }

        func run(using context: CommandContext, signature: Signature) async throws {
            prepareDependencies {
                $0.logger = Logger(component: "alerting")
            }
            @Dependency(\.logger) var logger

            logger.info("Running alerting...")

            let timePeriod = signature.duration
            let limit = signature.limit ?? Alerting.defaultLimit

            logger.info("Validation time interval: \(timePeriod.hours)h, limit: \(limit)")

            let builds = try await Alerting.fetchBuilds(on: context.application.db, timePeriod: timePeriod, limit: limit)
            try await Alerting.runBuildChecks(for: builds)
            try await Alerting.runMonitoring001Check(on: context.application.db, timePeriod: Alerting.checkMon001TimePeriod)
                .log(check: "CHECK_MON_001")
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

    static func runBuildChecks(for builds: [BuildInfo]) async throws {
        // to do
        // - [ ] doc gen is configured but it failed

        @Dependency(\.logger) var logger

        logger.info("Build records selected: \(builds.count)")
        if let oldest = builds.last {
            logger.info("Oldest selected: \(oldest.createdAt)")
        }
        if let mostRecent = builds.first {
            logger.info("Most recent selected: \(mostRecent.createdAt)")
        }
        builds.validateBuildsPresent().log(check: "CHECK_BUILDS_PRESENT")
        builds.validatePlatformsPresent().log(check: "CHECK_BUILDS_PLATFORMS_PRESENT")
        builds.validateSwiftVersionsPresent().log(check: "CHECK_BUILDS_SWIFT_VERSIONS_PRESENT")
        builds.validateRunnerIdsPresent().log(check: "CHECK_BUILDS_RUNNER_IDS_PRESENT")
        if builds.count >= 1000 {  // only run these tests if we have a decent number of builds, to reduce chance of false positives
            builds.validatePlatformsSuccessful().log(check: "CHECK_BUILDS_PLATFORMS_SUCCESSFUL")
            builds.validateSwiftVersionsSuccessful().log(check: "CHECK_BUILDS_SWIFT_VERSIONS_SUCCESSFUL")
            builds.validateRunnerIdsSuccessful().log(check: "CHECK_BUILDS_RUNNER_IDS_SUCCESSFUL")
            builds.validateSuccessRateInRange().log(check: "CHECK_BUILDS_SUCCESS_RATE_IN_RANGE")
        }
    }

    static func fetchBuilds(on database: Database, timePeriod: TimeAmount, limit: Int) async throws -> [Alerting.BuildInfo] {
        @Dependency(\.logger) var logger

        let start = Date.now
        defer {
            logger.debug("fetchBuilds elapsed: \(Date.now.timeIntervalSince(start).rounded(decimalPlaces: 2))s")
        }
        @Dependency(\.date.now) var now
        let cutoff = now.addingTimeInterval(-timePeriod.timeInterval)
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

    struct Mon001Row: Decodable, CustomStringConvertible {
        var owner: String
        var repository: String
        var status: Package.Status?
        var processingStage: Package.ProcessingStage?
        var updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case owner
            case repository
            case status
            case processingStage = "processing_stage"
            case updatedAt = "updated_at"
        }

        var description: String {
            "\(owner)/\(repository) \(status.map { $0.rawValue } ?? "-") \(processingStage.map { $0.rawValue } ?? "-") \(updatedAt)"
        }
    }

    static func runMonitoring001Check(on database: Database, timePeriod: TimeAmount) async throws -> Alerting.Validation {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        let rows = try await db.raw("""
            SELECT
              r.owner,
              r.name AS "repository",
              p.status,
              p.processing_stage,
              p.updated_at
            FROM
              repositories r
              JOIN packages p ON r.package_id = p.id
            WHERE
              p.updated_at < now() - INTERVAL \(literal: "\(timePeriod.hours) hours")
            ORDER BY
              p.updated_at
            """)
            .all(decoding: Mon001Row.self)
        return rows.isValid()
    }
}


extension Alerting {
    enum Validation: Equatable {
        case ok
        case failed(reasons: [String])

        func log(check: String) {
            @Dependency(\.logger) var logger
            switch self {
                case .ok:
                    logger.debug("\(check) passed")
                case .failed(let reasons):
                    if reasons.count >= 5 {
                        logger.critical("\(check) failures: \(reasons.count)")
                    }
                    for reason in reasons {
                        logger.critical("\(check) failed: \(reason)")
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
        return .failed(reasons: notSeen.sorted().map { "Missing Swift version: \($0, droppingZeroes: .patch)" })
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
        return .failed(reasons: noSuccess.sorted().map { "Swift version without successful builds: \($0, droppingZeroes: .patch)" })
    }

    func validateRunnerIdsPresent() -> Alerting.Validation {
        @Dependency(\.environment) var environment
        var notSeen = Set(environment.runnerIds())
        for build in self where build.runnerId != nil {
            notSeen.remove(build.runnerId!)
            if notSeen.isEmpty { return .ok }
        }
        return .failed(reasons: notSeen.sorted().map { "Missing runner id: \($0)" })
    }

    func validateRunnerIdsSuccessful() -> Alerting.Validation {
        @Dependency(\.environment) var environment
        var noSuccess = Set(environment.runnerIds())
        for build in self where build.runnerId != nil && build.status == .ok {
            noSuccess.remove(build.runnerId!)
            if noSuccess.isEmpty { return .ok }
        }
        return .failed(reasons: noSuccess.sorted().map { "Runner id without successful builds: \($0)" })
    }

    func validateSuccessRateInRange() -> Alerting.Validation {
        let successRate = Double(filter { $0.status == .ok }.count) / Double(count)
        // Success rate has been around 30% generally
        if 0.2 <= successRate && successRate <= 0.4 {
            return .ok
        } else {
            let percentSuccessRate = (successRate * 1000).rounded() / 10
            return .failed(reasons: ["Global success rate of \(percentSuccessRate)% out of bounds"])
        }
    }
}


extension [Alerting.Mon001Row] {
    func isValid() -> Alerting.Validation {
        if isEmpty {
            return .ok
        } else {
            return .failed(reasons: sorted(by: { $0.updatedAt < $1.updatedAt }).map { "Outdated package: \($0)" })
        }
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
        let scale = Double.pow(10, decimalPlaces)
        return (self * scale).rounded(.toNearestOrAwayFromZero) / scale
    }
}
