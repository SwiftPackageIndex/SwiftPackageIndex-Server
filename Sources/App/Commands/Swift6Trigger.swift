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


struct Swift6TriggerCommand: AsyncCommand {
    static let defaultLimit = 1

    struct Signature: CommandSignature {
        @Flag(name: "dry-run", short: "d", help: "simulate triggers but don't run them")
        var dryRun: Bool

        @Flag(name: "force", short: "f", help: "override pipeline capacity check")
        var force: Bool

        @Option(name: "limit", short: "l")
        var limit: Int?
    }

    var help: String { "Trigger Swift 6 builds" }

    func run(using context: CommandContext, signature: Signature) async throws {
        let logger = Logger(component: "swift-6-trigger")

        do {
            if signature.dryRun {
                logger.info("Dry run mode: simulating triggers")
            }
            try await Self.triggerBuilds(on: context.application.db,
                                         client: context.application.client,
                                         limit: signature.limit ?? Self.defaultLimit,
                                         dryRun: signature.dryRun,
                                         force: signature.force)
        } catch {
            logger.critical("\(error)")
        }
    }

    func printUsage(using context: CommandContext) {
        var context = context
        outputHelp(using: &context)
    }
}


extension Swift6TriggerCommand {
    
    static func triggerBuilds(on database: Database, client: Client, limit: Int, dryRun: Bool, force: Bool) async throws {
        Current.logger().info("Triggering Swift 6 builds (limit: \(limit)) ...")
        
        let candidates = try await fetchBuildCandidates(database)        
        let triggers = Array(candidates.prefix(limit))
        
        try await triggerBuilds(on: database, client: client, triggers: triggers, dryRun: dryRun, force: force)
    }
    
    
    static func fetchBuildCandidates(_ database: Database) async throws -> [(versionId: Version.Id, platform: Build.Platform)] {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }

        struct Row: Decodable {
            var versionId: Version.Id
            var platform: Build.Platform

            enum CodingKeys: String, CodingKey {
                case versionId = "version_id"
                case platform
            }
        }

        let query: SQLQueryString = """
            select t.id version_id, t.platform
            from (
                select v.id, 'macos-spm' as "platform"
                from versions v
                where v.latest = 'default_branch'
                and v.id not in (
                    select v.id
                    from builds b
                    join versions v on b.version_id = v.id
                    where swift_version->>'major' = '6'
                    and platform = 'macos-spm'
                )
                union
                select v.id, 'linux' as "platform"
                from versions v
                where v.latest = 'default_branch'
                and v.id not in (
                    select v.id
                    from builds b
                    join versions v on b.version_id = v.id
                    where swift_version->>'major' = '6'
                    and platform = 'linux'
                )
            ) t
            """

        return try await db.raw(query)
            .all(decoding: Row.self)
            .map { ($0.versionId, $0.platform) }
    }

    
    static func triggerBuilds(on database: Database,
                              client: Client,
                              triggers: [(versionId: Version.Id, platform: Build.Platform)],
                              dryRun: Bool,
                              force: Bool) async throws {
        guard Current.allowBuildTriggers() else {
            Current.logger().info("Build trigger override switch OFF - no builds are being triggered")
            return
        }

        if force {
            Current.logger().info("Skipping pending pipeline check")
        } else {
            let pendingJobs = try await Current.getStatusCount(client, .pending).get()
            guard pendingJobs + triggers.count < Current.gitlabPipelineLimit() else {
                Current.logger().info("too many pending pipelines (\(pendingJobs))")
                return
            }
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for trigger in triggers {
                group.addTask {
                    let triggerInfo = BuildTriggerInfo(versionId: trigger.versionId, buildPairs: [.init(trigger.platform, .v6_0)])!
                    if dryRun {
                        Current.logger().info("Simulating triggering build (\(trigger.versionId), \(trigger.platform))")
                    } else {
                        try await triggerBuildsUnchecked(on: database, client: client, triggers: [triggerInfo])
                    }
                }
            }
            try await group.waitForAll()
        }
    }

}


extension SwiftVersion {
    static let v6_0: Self = .init(6, 0, 0)
}
