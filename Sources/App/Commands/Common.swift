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

import Fluent
import PostgresNIO
import Vapor


/// Update packages (in the `[Result<Joined<Package, Repository>, Error>]` array).
///
/// Unlike the overload with a result parameter `Result<(Joined<Package, Repository>, [Version])` this will not use `Version` information to update the package.
///
/// - Parameters:
///   - client: `Client` object
///   - database: `Database` object
///   - logger: `Logger` object
///   - results: `Joined<Package, Repository>` results to update
///   - stage: Processing stage
func updatePackages(client: Client,
                    database: Database,
                    logger: Logger,
                    results: [Result<Joined<Package, Repository>, Error>],
                    stage: Package.ProcessingStage) async throws {
    let updates = await withThrowingTaskGroup(of: Void.self) { group in
        for result in results {
            group.addTask {
                try await updatePackage(client: client,
                                        database: database,
                                        logger: logger,
                                        result: result,
                                        stage: stage)
            }
        }
        return await group.results()
    }
    logger.debug("updateStatus ops: \(updates.count)")
}


/// Update packages (in the `[Result<(Joined<Package, Repository>, [Version])]` array).
///
/// This overload will use `Version` information to update the package, for example to compute a new package score.
///
/// - Parameters:
///   - client: `Client` object
///   - database: `Database` object
///   - logger: `Logger` object
///   - results: `(Joined<Package, Repository>, [Version])` results to update
///   - stage: Processing stage
func updatePackages(client: Client,
                    database: Database,
                    logger: Logger,
                    results: [Result<(Joined<Package, Repository>, [Version]), Error>],
                    stage: Package.ProcessingStage) async throws {
    let updates = await withThrowingTaskGroup(of: Void.self) { group in
        for result in results {
            group.addTask {
                try await updatePackage(client: client,
                                        database: database,
                                        logger: logger,
                                        result: result,
                                        stage: stage)
            }
        }
        return await group.results()
    }
    logger.debug("updateStatus ops: \(updates.count)")
}


func updatePackage(client: Client,
                   database: Database,
                   logger: Logger,
                   result: Result<(Joined<Package, Repository>, [Version]), Error>,
                   stage: Package.ProcessingStage) async throws {
    // Compute the package score and update the result before passing it to `updatePackage`
    let result = result.map {
        let (jpr, versions) = $0
        jpr.package.score = Score.compute(package: jpr, versions: versions)
        return jpr
    }

    try await updatePackage(client: client,
                            database: database,
                            logger: logger,
                            result: result,
                            stage: stage)
}


func updatePackage(client: Client,
                   database: Database,
                   logger: Logger,
                   result: Result<Joined<Package, Repository>, Error>,
                   stage: Package.ProcessingStage) async throws {
    switch result {
        case .success(let jpr):
            let pkg = jpr.package
            if stage == .ingestion && pkg.status == .new {
                // newly ingested package: leave status == .new for fast-track
                // analysis
            } else {
                pkg.status = .ok
            }
            pkg.processingStage = stage
            do {
                try await pkg.update(on: database)
            } catch {
                logger.report(error: error)
                try await Current.reportError(client, .critical, error)
            }

        case .failure(let error) where error as? PostgresNIO.PostgresError != nil:
            // Escalate database errors to critical
            try? await Current.reportError(client, .critical, error)
            try await recordError(database: database, error: error, stage: stage)

        case .failure(let error):
            try? await Current.reportError(client, .error, error)
            try await recordError(database: database, error: error, stage: stage)
    }
}


func recordError(database: Database,
                 error: Error,
                 stage: Package.ProcessingStage) async throws {
    func setStatus(id: Package.Id?, status: Package.Status) async throws {
        guard let id = id else { return }
        try await Package.query(on: database)
            .filter(\.$id == id)
            .set(\.$processingStage, to: stage)
            .set(\.$status, to: status)
            .update()
    }

    switch error as? AppError {
        case .noValidVersions:
            // don't log, too common and unimportant
            break
        default:
            database.logger.error("\(stage) error: \(error.localizedDescription)")
    }

    guard let error = error as? AppError else { return }
    
    switch error {
        case let .analysisError(id, _):
            try await setStatus(id: id, status: .analysisFailed)
        case .envVariableNotSet, .shellCommandFailed:
            break
        case let .genericError(id, _):
            try await setStatus(id: id, status: .ingestionFailed)
        case let .invalidPackageCachePath(id, _):
            try await setStatus(id: id, status: .invalidCachePath)
        case let .cacheDirectoryDoesNotExist(id, _):
            try await setStatus(id: id, status: .cacheDirectoryDoesNotExist)
        case let .invalidPackageUrl(id, _):
            try await setStatus(id: id, status: .invalidUrl)
        case let .invalidRevision(id, _):
            try await setStatus(id: id, status: .analysisFailed)
        case let .metadataRequestFailed(id, _, _):
            try await setStatus(id: id, status: .metadataRequestFailed)
        case let .noValidVersions(id, _):
            try await setStatus(id: id, status: .noValidVersions)
    }
}
