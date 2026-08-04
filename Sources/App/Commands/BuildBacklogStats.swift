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
import Vapor


enum BuildBacklogStats {
    struct Command: AsyncCommand {
        var help: String { "Show build backlog statistics" }

        struct Signature: CommandSignature {
            @Option(name: "limit", short: "l")
            var limit: Int?

            @Flag(name: "without-latest-swift-version")
            var withoutLatestSwiftVersion: Bool
        }

        func run(using context: CommandContext, signature: Signature) async throws {
            prepareDependencies {
                $0.logger = Logger(component: "build-backlog-stats")
            }
            @Dependency(\.logger) var logger

            logger.info("Running build-backlog-stats...")

            let packageIds = try await fetchBuildCandidates(
                context.application.db,
                withLatestSwiftVersion: !signature.withoutLatestSwiftVersion
            )

            if let limit = signature.limit {
                logger.info("Checking \(limit) of \(packageIds.count) candidates...")
            } else {
                logger.info("Checkign all \(packageIds.count) candidates")
            }

            var totalBuildCount = 0
            var platformCounts = [Build.Platform: Int]()
            var swiftVersionCounts = [SwiftVersion: Int]()

            for (idx, pkgId) in packageIds.prefix(signature.limit ?? packageIds.count).enumerated() {
                if idx > 0, idx % 50 == 0 {
                    logger.info("Checking candidate #\(idx)")
                }
                let triggerInfo = try await findMissingBuilds(
                    context.application.db,
                    packageId: pkgId
                )
                for trigger in triggerInfo {
                    for pair in trigger.buildPairs {
                        totalBuildCount += 1
                        platformCounts[pair.platform, default: 0] += 1
                        swiftVersionCounts[pair.swiftVersion, default: 0] += 1
                    }
                }
            }

            logger.info("Total build count: \(totalBuildCount)")

            for platform in Build.Platform.allActive {
                if let count = platformCounts[platform] {
                    logger.info("\(platform): \(count)")
                }
            }

            for swiftVersion in SwiftVersion.allActive {
                if let count = swiftVersionCounts[swiftVersion] {
                    logger.info("\(swiftVersion): \(count)")
                }
            }
        }
    }
}
