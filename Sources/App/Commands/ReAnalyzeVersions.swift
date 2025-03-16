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
import Vapor


enum ReAnalyzeVersions {

    struct Command: AsyncCommand {
        let defaultBatchSize = 10
        let defaultLimit = 1

        struct Signature: CommandSignature {
            @Option(name: "batchSize", short: "b")
            var batchSize: Int?

            @Option(name: "before")
            var before: Date?

            @Option(name: "packageId", short: "p")
            var packageId: Package.Id?

            @Option(name: "limit", short: "l")
            var limit: Int?

            @Flag(name: "refresh-checkouts", short: "r")
            var refreshCheckouts: Bool
        }

        var help: String { "Run version re-analysis" }

        func run(using context: CommandContext, signature: Signature) async throws {
            prepareDependencies {
                $0.logger = Logger(component: "re-analyze-versions")
            }
            @Dependency(\.logger) var logger
            @Dependency(\.date.now) var now

            let limit = signature.limit ?? defaultLimit
            let client = context.application.client
            let db = context.application.db

            if let id = signature.packageId {
                logger.info("Re-analyzing versions (id: \(id)) ...")
                do {
                    try await reAnalyzeVersions(
                        client: client,
                        database: db,
                        versionsLastUpdatedBefore: now,
                        refreshCheckouts: signature.refreshCheckouts,
                        packageId: id
                    )
                } catch {
                    logger.error("\(error.localizedDescription)")
                }
            } else {
                guard let cutoffDate = signature.before else {
                    logger.info("No cut-off date set, skipping re-analysis")
                    return
                }

                logger.info("Re-analyzing versions (limit: \(limit)) ...")
                var processed = 0
                while processed < limit {
                    let currentBatchSize = min(signature.batchSize ?? defaultBatchSize,
                                               limit - processed)
                    logger.info("Re-analyzing versions (batch: \(processed)..<\(processed + currentBatchSize)) ...")
                    do {
                        try await reAnalyzeVersions(
                            client: client,
                            database: db,
                            before: cutoffDate,
                            refreshCheckouts: signature.refreshCheckouts,
                            limit: currentBatchSize
                        )
                        processed += currentBatchSize
                    } catch {
                        logger.error("\(error.localizedDescription)")
                    }
                }
            }
            do {
                try await AppMetrics.push(client: client, jobName: "re-analyze-versions")
            } catch {
                logger.warning("\(error.localizedDescription)")
            }

            logger.info("Done.")
        }
    }


    /// Re-analyze outdated versions for a given `Package`, identified by its `Id`.
    /// - Parameters:
    ///   - client: `Client` object
    ///   - database: `Database` object
    ///   - threadPool: `NIOThreadPool` (for running shell commands)
    ///   - versionsLastUpdatedBefore: `Date` cut-off for versions to update
    ///   - packages: packages to be analysed
    /// - Returns: future
    static func reAnalyzeVersions(client: Client,
                                  database: Database,
                                  versionsLastUpdatedBefore cutOffDate: Date,
                                  refreshCheckouts: Bool,
                                  packageId: Package.Id) async throws {
        let pkg = try await Package.fetchCandidate(database, id: packageId)
        try await reAnalyzeVersions(client: client,
                                    database: database,
                                    before: cutOffDate,
                                    refreshCheckouts: refreshCheckouts,
                                    packages: [pkg])
    }


    /// Re-analyze outdated versions.
    /// - Parameters:
    ///   - client: `Client` object
    ///   - database: `Database` object
    ///   - threadPool: `NIOThreadPool` (for running shell commands)
    ///   - versionsLastUpdatedBefore: `Date` cut-off for versions to update
    ///   - packages: packages to be analysed
    /// - Returns: future
    static func reAnalyzeVersions(client: Client,
                                  database: Database,
                                  before cutOffDate: Date,
                                  refreshCheckouts: Bool,
                                  limit: Int) async throws {
        let pkgs = try await Package.fetchReAnalysisCandidates(database,
                                                               before: cutOffDate,
                                                               limit: limit)
        try await reAnalyzeVersions(client: client,
                                    database: database,
                                    before: cutOffDate,
                                    refreshCheckouts: refreshCheckouts,
                                    packages: pkgs)
    }


    /// Re-analyze outdated versions for the given list of `Package`s.
    /// - Parameters:
    ///   - client: `Client` object
    ///   - database: `Database` object
    ///   - threadPool: `NIOThreadPool` (for running shell commands)
    ///   - versionsLastUpdatedBefore: `Date` cut-off for versions to update
    ///   - packages: packages to be analysed
    /// - Returns: future
    static func reAnalyzeVersions(client: Client,
                                  database: Database,
                                  before cutoffDate: Date,
                                  refreshCheckouts: Bool,
                                  packages: [Joined<Package, Repository>]) async throws {
        // Pick essentials parts of companion function `analyze` and run the for
        // re-analysis.
        //
        // We don't refresh checkouts, because these are being refreshed in `analyze`
        // and would race unnecessarily if we also tried to refresh them here.
        //
        // Care should be taken to ensure `reAnalyzeVersions` operates on a
        // set of versions that is distinct from those `analyze` updates, to
        // avoid data races.
        //
        // Since `reAnalyzeVersions` only updates existing versions, this will be the
        // case by design, as `analyze` will only add or remove versions, ignoring
        // existing ones.

        @Dependency(\.logger) var logger

        for pkg in packages {
            logger.info("Re-analyzing package \(pkg.model.url) ...")

            // 2024-10-05 sas: We need to explicitly weave dependencies into the `transaction` closure, because escaping closures strip them.
            // https://github.com/pointfreeco/swift-dependencies/discussions/283#discussioncomment-10846172
            // This might not be needed in Vapor 5 / FluentKit 2
            // TODO: verify this is still needed once we upgrade to Vapor 5 / FluentKit 2
            try await withEscapedDependencies { dependencies in
                try await database.transaction { tx in
                    try await dependencies.yield {
                        @Dependency(\.fileManager) var fileManager
                        guard let cacheDir = fileManager.cacheDirectoryPath(for: pkg.model) else { return }
                        if !fileManager.fileExists(atPath: cacheDir) || refreshCheckouts {
                            try await Analyze.refreshCheckout(package: pkg)
                        }
                        
                        let versions = try await getExistingVersions(client: client,
                                                                     transaction: tx,
                                                                     package: pkg,
                                                                     before: cutoffDate)
                        logger.info("Updating \(versions.count) versions (id: \(pkg.model.id)) ...")

                        try await setUpdatedAt(on: tx, versions: versions)
                        
                        Analyze.mergeReleaseInfo(package: pkg, into: versions)
                        
                        for version in versions {
                            let pkgInfo: Analyze.PackageInfo
                            do {
                                pkgInfo = try await Analyze.getPackageInfo(package: pkg, version: version)
                            } catch {
                                logger.report(error: error)
                                continue
                            }
                            
                            try await Analyze.updateVersion(on: tx, version: version, packageInfo: pkgInfo)
                            try await Analyze.recreateProducts(on: tx, version: version, manifest: pkgInfo.packageManifest)
                            try await Analyze.recreateTargets(on: tx, version: version, manifest: pkgInfo.packageManifest)
                        }
                        
                        // No need to run `updateLatestVersions` because we're only operating on existing versions,
                        // not adding any new ones that could change the `latest` marker.
                    }
                }
            }
        }
    }


    static func getExistingVersions(client: Client,
                                    transaction: Database,
                                    package: Joined<Package, Repository>,
                                    before cutoffDate: Date) async throws -> [Version] {
        let delta = try await Analyze.diffVersions(client: client,
                                                   transaction: transaction,
                                                   package: package)
        return delta.toKeep.filter {
            $0.updatedAt != nil && $0.updatedAt! < cutoffDate
        }
    }


    static func setUpdatedAt(on database: Database, versions: [Version]) async throws {
        @Dependency(\.date.now) var now
        for version in versions {
            version.updatedAt = now
        }
        try await versions.save(on: database)
    }

}


extension Package {
    static func fetchReAnalysisCandidates(
        _ database: Database,
        before cutOffDate: Date,
        limit: Int) async throws -> [Joined<Package, Repository>] {
            try await Joined.query(on: database)
                .join(Version.self, on: \Package.$id == \Version.$package.$id)
                .filter(Version.self, \.$updatedAt < cutOffDate)
                .fields(for: Package.self)
                .fields(for: Repository.self)
                .unique()
                .sort(\.$updatedAt)
                .limit(limit)
                .all()
        }
}
