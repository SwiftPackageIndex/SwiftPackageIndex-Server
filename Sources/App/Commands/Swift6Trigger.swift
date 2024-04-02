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
import Vapor


struct Swift6TriggerCommand: AsyncCommand {
    let defaultLimit = 1

    struct Signature: CommandSignature {
        @Option(name: "limit", short: "l")
        var limit: Int?

        @Flag(name: "force", short: "f", help: "override pipeline capacity check and downscaling (--id only)")
        var force: Bool

        @Option(name: "package-id", short: "i")
        var packageId: Package.Id?

        @Option(name: "platform", short: "p")
        var platform: Build.Platform?

        @Option(name: "swift-version", short: "s")
        var swiftVersion: SwiftVersion?

        @Option(name: "version-id", short: "v")
        var versionId: Version.Id?
    }

    var help: String { "Trigger Swift 6 builds" }

    enum Mode {
        case limit(Int)
        case packageId(Package.Id, force: Bool)
        case triggerInfo(Version.Id, BuildPair)
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        let logger = Logger(component: "swift-6-trigger")

        let mode: Mode
        switch (signature.limit, signature.packageId, signature.versionId) {
            case let (.some(limit), .none, .none):
                mode = .limit(limit)

            case let (.none, .some(packageId), .none):
                mode = .packageId(packageId, force: signature.force)

            case let (.none, .none, .some(versionId)):
                guard let platform = signature.platform,
                      let swiftVersion = signature.swiftVersion else {
                    printUsage(using: context)
                    return
                }
                let buildPair = BuildPair(platform, swiftVersion)
                mode = .triggerInfo(versionId, buildPair)

            case (.none, .none, .none):
                mode = .limit(defaultLimit)

            default:
                printUsage(using: context)
                return
        }

        do {
//            try await Self.triggerBuilds(on: context.application.db,
//                                         client: context.application.client,
//                                         logger: logger,
//                                         mode: mode)
        } catch {
            logger.critical("\(error)")
        }

        do {
            try await AppMetrics.push(client: context.application.client,
                                      logger: context.application.logger,
                                      jobName: "trigger-builds")
        } catch {
            logger.warning("\(error)")
        }
    }

    func printUsage(using context: CommandContext) {
        var context = context
        outputHelp(using: &context)
    }
}


extension Swift6TriggerCommand {
//    static func triggerBuilds(on database: Database,
//                              client: Client,
//                              logger: Logger,
//                              mode: Mode) async throws {
//        let start = DispatchTime.now().uptimeNanoseconds
//        switch mode {
//            case .limit(let limit):
//                logger.info("Triggering builds (limit: \(limit)) ...")
//
//                let withLatestSwiftVersion = Current.buildTriggerCandidatesWithLatestSwiftVersion
//                let candidates = try await fetchBuildCandidates(database,
//                                                                withLatestSwiftVersion: withLatestSwiftVersion)
//                AppMetrics.buildCandidatesCount?.set(candidates.count)
//
//                let limitedCandidates = Array(candidates.prefix(limit))
//                try await triggerBuilds(on: database,
//                                        client: client,
//                                        logger: logger,
//                                        packages: limitedCandidates)
//                AppMetrics.buildTriggerDurationSeconds?.time(since: start)
//
//            case let .packageId(id, force):
//                logger.info("Triggering builds (packageID: \(id)) ...")
//                try await triggerBuilds(on: database,
//                                        client: client,
//                                        logger: logger,
//                                        packages: [id],
//                                        force: force)
//                AppMetrics.buildTriggerDurationSeconds?.time(since: start)
//
//            case let .triggerInfo(versionId, buildPair):
//                logger.info("Triggering builds (versionID: \(versionId), \(buildPair)) ...")
//                guard let trigger = BuildTriggerInfo(versionId: versionId,
//                                                     buildPairs: [buildPair]) else {
//                    logger.error("Failed to create trigger.")
//                    return
//                }
//                try await triggerBuildsUnchecked(on: database,
//                                                 client: client,
//                                                 logger: logger,
//                                                 triggers: [trigger])
//
//        }
//    }
}
