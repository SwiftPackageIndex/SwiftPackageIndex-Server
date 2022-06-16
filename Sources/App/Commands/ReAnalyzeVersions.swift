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


struct ReAnalyzeVersionsCommand: Command {
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

    func run(using context: CommandContext, signature: Signature) throws {
        let limit = signature.limit ?? defaultLimit

        let client = context.application.client
        let db = context.application.db
        let logger = Logger(component: "re-analyze-versions")
        let threadPool = context.application.threadPool

        if let id = signature.id {
            logger.info("Re-analyzing versions (id: \(id)) ...")
            try reAnalyzeVersions(client: client,
                                  database: db,
                                  logger: logger,
                                  threadPool: threadPool,
                                  versionsLastUpdatedBefore: Current.date(),
                                  id: id)
                .wait()
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
                logger.info("Re-analyzing versions (batch: \(processed)..<\(processed + currentBatchSize) ...")
                try reAnalyzeVersions(client: client,
                                      database: db,
                                      logger: logger,
                                      threadPool: threadPool,
                                      before: cutoffDate,
                                      limit: currentBatchSize)
                .wait()
                processed += currentBatchSize
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

        logger.info("done.")
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
func reAnalyzeVersions(client: Client,
                       database: Database,
                       logger: Logger,
                       threadPool: NIOThreadPool,
                       versionsLastUpdatedBefore cutOffDate: Date,
                       id: Package.Id) -> EventLoopFuture<Void> {
    Package.fetchCandidate(database, id: id)
        .map { [$0] }
        .flatMap { reAnalyzeVersions(client: client,
                                     database: database,
                                     logger: logger,
                                     threadPool: threadPool,
                                     before: cutOffDate,
                                     packages: $0) }
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
func reAnalyzeVersions(client: Client,
                       database: Database,
                       logger: Logger,
                       threadPool: NIOThreadPool,
                       before cutOffDate: Date,
                       limit: Int) -> EventLoopFuture<Void> {
    Package.fetchReAnalysisCandidates(database,
                                      before: cutOffDate,
                                      limit: limit)
        .flatMap { reAnalyzeVersions(client: client,
                                     database: database,
                                     logger: logger,
                                     threadPool: threadPool,
                                     before: cutOffDate,
                                     packages: $0) }
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
func reAnalyzeVersions(client: Client,
                       database: Database,
                       logger: Logger,
                       threadPool: NIOThreadPool,
                       before cutoffDate: Date,
                       packages: [Joined<Package, Repository>]) -> EventLoopFuture<Void> {
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

    database.transaction { tx in
        getExistingVersions(client: client,
                            logger: logger,
                            threadPool: threadPool,
                            transaction: tx,
                            packages: packages,
                            before: cutoffDate)
            .flatMap { setUpdatedAt(on: tx, packageVersions: $0) }
            .map { results in
                for result in results {
                    if let (pkg, versions) = try? result.get() {
                        Analyze.mergeReleaseInfo(package: pkg, into: versions)
                    }
                }
                return results
            }
            .map { Analyze.getPackageInfo(packageAndVersions: $0) }
            .flatMap { Analyze.updateVersions(on: tx, packageResults: $0) }
            .flatMap { Analyze.updateProducts(on: tx, packageResults: $0) }
            .flatMap { Analyze.updateTargets(on: tx, packageResults: $0) }
    }
    .transform(to: ())
}


func getExistingVersions(client: Client,
                         logger: Logger,
                         threadPool: NIOThreadPool,
                         transaction: Database,
                         packages: [Joined<Package, Repository>],
                         before cutoffDate: Date) -> EventLoopFuture<[Result<(Joined<Package, Repository>, [Version]), Error>]> {
    EventLoopFuture.whenAllComplete(
        packages.map { pkg in
            Analyze.diffVersions(client: client,
                                 logger: logger,
                                 transaction: transaction,
                                 package: pkg)
                .map {
                    (pkg, $0.toKeep.filter {
                        $0.updatedAt != nil && $0.updatedAt! < cutoffDate
                    })
                }
                .map { pkg, versions in
                    logger.info("updating \(versions.count) versions (id: \(pkg.model.id)) ...")
                    return (pkg, versions)
                }
        },
        on: transaction.eventLoop
    )
}


func setUpdatedAt(on database: Database,
                  packageVersions: [Result<(Joined<Package, Repository>, [Version]), Error>]) -> EventLoopFuture<[Result<(Joined<Package, Repository>, [Version]), Error>]> {
    packageVersions.whenAllComplete(on: database.eventLoop) { pkg, versions in
        versions
            .map { version -> Version in
                version.updatedAt = Current.date()
                return version
            }
            .save(on: database)
            .map { (pkg, versions) }
    }
}


extension Package {
    static func fetchReAnalysisCandidates(
        _ database: Database,
        before cutOffDate: Date,
        limit: Int) -> EventLoopFuture<[Joined<Package, Repository>]> {
            Joined.query(on: database)
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
