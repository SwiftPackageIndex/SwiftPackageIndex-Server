// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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

import Vapor
import Fluent


enum ReAnalyzeVersions {

    struct Command: CommandAsync {
        let defaultBatchSize = 10
        let defaultLimit = 1

        struct Signature: CommandSignature {
            @Option(name: "batchSize", short: "b")
            var batchSize: Int?
            @Option(name: "limit", short: "l")
            var limit: Int?
            @Option(name: "id")
            var id: UUID?
            @Option(name: "before")
            var before: Date?
        }

        var help: String { "Run version re-analysis" }

        func run(using context: CommandContext, signature: Signature) async {
            let limit = signature.limit ?? defaultLimit

            let client = context.application.client
            let db = context.application.db
            let logger = Logger(component: "re-analyze-versions")

            if let id = signature.id {
                logger.info("Re-analyzing versions (id: \(id)) ...")
                do {
                    try await reAnalyzeVersions(client: client,
                                                database: db,
                                                logger: logger,
                                                versionsLastUpdatedBefore: Current.date(),
                                                id: id)
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
                        try await reAnalyzeVersions(client: client,
                                                    database: db,
                                                    logger: logger,
                                                    before: cutoffDate,
                                                    limit: currentBatchSize)
                        processed += currentBatchSize
                    } catch {
                        logger.error("\(error.localizedDescription)")
                    }
                }
            }
            do {
                try AppMetrics.push(client: client,
                                    logger: logger,
                                    jobName: "re-analyze-versions")
                .wait()
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
    ///   - logger: `Logger` object
    ///   - threadPool: `NIOThreadPool` (for running shell commands)
    ///   - versionsLastUpdatedBefore: `Date` cut-off for versions to update
    ///   - packages: packages to be analysed
    /// - Returns: future
    static func reAnalyzeVersions(client: Client,
                                  database: Database,
                                  logger: Logger,
                                  versionsLastUpdatedBefore cutOffDate: Date,
                                  id: Package.Id) async throws {
        let pkg = try await Package.fetchCandidate(database, id: id).get()
        try await reAnalyzeVersions(client: client,
                                    database: database,
                                    logger: logger,
                                    before: cutOffDate,
                                    packages: [pkg])
    }


    /// Re-analyze outdated versions.
    /// - Parameters:
    ///   - client: `Client` object
    ///   - database: `Database` object
    ///   - logger: `Logger` object
    ///   - threadPool: `NIOThreadPool` (for running shell commands)
    ///   - versionsLastUpdatedBefore: `Date` cut-off for versions to update
    ///   - packages: packages to be analysed
    /// - Returns: future
    static func reAnalyzeVersions(client: Client,
                                  database: Database,
                                  logger: Logger,
                                  before cutOffDate: Date,
                                  limit: Int) async throws {
        let pkgs = try await Package.fetchReAnalysisCandidates(database,
                                                               before: cutOffDate,
                                                               limit: limit)
        try await reAnalyzeVersions(client: client,
                                    database: database,
                                    logger: logger,
                                    before: cutOffDate,
                                    packages: pkgs)
    }


    /// Re-analyze outdated versions for the given list of `Package`s.
    /// - Parameters:
    ///   - client: `Client` object
    ///   - database: `Database` object
    ///   - logger: `Logger` object
    ///   - threadPool: `NIOThreadPool` (for running shell commands)
    ///   - versionsLastUpdatedBefore: `Date` cut-off for versions to update
    ///   - packages: packages to be analysed
    /// - Returns: future
    static func reAnalyzeVersions(client: Client,
                                  database: Database,
                                  logger: Logger,
                                  before cutoffDate: Date,
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

        for pkg in packages {
            logger.info("Re-analyzing package \(pkg.model.url) ...")

            try await database.transaction { tx in
                guard let cacheDir = Current.fileManager.cacheDirectoryPath(for: pkg.model) else { return }
                if !Current.fileManager.fileExists(atPath: cacheDir) {
                    try Analyze.refreshCheckout(logger: logger, package: pkg)
                }

                let versions = try await getExistingVersions(client: client,
                                                             logger: logger,
                                                             transaction: tx,
                                                             package: pkg,
                                                             before: cutoffDate)
                logger.info("Updating \(versions.count) versions (id: \(pkg.model.id)) ...")

                try await setUpdatedAt(on: tx, package: pkg, versions: versions)

                Analyze.mergeReleaseInfo(package: pkg, into: versions)

                let versionsPkgInfo = versions.compactMap { version -> (Version, Analyze.PackageInfo)? in
                    guard let pkgInfo = try? Analyze.getPackageInfo(package: pkg, version: version) else { return nil }
                    return (version, pkgInfo)
                }

                let docArchivesByRef = versionsPkgInfo.filter(\.1.hasDocumentationTargets).isEmpty
                ? [:]
                : try await Analyze.getDocArchives(for: pkg)?.archivesGroupedByRef() ?? [:]

                for (version, pkgInfo) in versionsPkgInfo {
                    try await Analyze.updateVersion(on: tx,
                                                    version: version,
                                                    docArchivesByRef: docArchivesByRef,
                                                    packageInfo: pkgInfo).get()
                    try await Analyze.recreateProducts(on: tx,
                                                       version: version,
                                                       manifest: pkgInfo.packageManifest)
                    try await Analyze.recreateTargets(on: tx,
                                                      version: version,
                                                      manifest: pkgInfo.packageManifest)
                }

                // No need to run `updateLatestVersions` because we're only operating on existing versions,
                // not adding any new ones that could change the `latest` marker.
            }
        }
    }


    static func getExistingVersions(client: Client,
                                    logger: Logger,
                                    transaction: Database,
                                    package: Joined<Package, Repository>,
                                    before cutoffDate: Date) async throws -> [Version] {
        let delta = try await Analyze.diffVersions(client: client,
                                                   logger: logger,
                                                   transaction: transaction,
                                                   package: package)
        return delta.toKeep.filter {
            $0.updatedAt != nil && $0.updatedAt! < cutoffDate
        }
    }


    static func setUpdatedAt(on database: Database, package: Joined<Package, Repository>, versions: [Version]) async throws {
        for version in versions {
            version.updatedAt = Current.date()
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
