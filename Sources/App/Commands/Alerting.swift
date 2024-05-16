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
        // - [ ] there are no builds for a certain Swift version
        // - [ ] there are no builds for a certain runnerId
        // - [ ] there are no successful builds for a certain platform
        // - [ ] there are no successful builds for a certain Swift version
        // - [ ] there are no successful builds for a certain runnerId
        // - [ ] the success ratio is not around 30%

        if builds.isEmpty {
            Current.logger().critical("No builds within the last \(timePeriod)h")
        }
        builds.validatePlatforms(period: timePeriod).log(check: "CHECK_BUILD_PLATFORMS")
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
    func validatePlatforms(period: TimeAmount) -> Alerting.Validation {
        var platformsNotSeen = Set(Build.Platform.allCases)
        for build in self {
            platformsNotSeen.remove(build.platform)
            if platformsNotSeen.isEmpty { return .ok }
        }
        return .failed(reasons: platformsNotSeen.sorted().map { "Missing platform: \($0)" })
    }
}


private extension TimeAmount {
    var timeInterval: TimeInterval {
        Double(nanoseconds) * 1e-9
    }
}
