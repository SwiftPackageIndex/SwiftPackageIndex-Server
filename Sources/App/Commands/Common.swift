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


func updatePackages(client: Client,
                    database: Database,
                    logger: Logger,
                    results: [Result<Joined<Package, Repository>, Error>],
                    stage: Package.ProcessingStage) -> EventLoopFuture<Void> {
    let updates = results.map { result -> EventLoopFuture<Void> in
        switch result {
            case .success(let jpr):
                let pkg = jpr.model
                // FIXME: Only load significant `latest` version records and release count here and change Score.compute to take those as parameters instead of all versions. We need the defaultBranch and latest stable versions for current score calculations.
                // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1470
                return pkg.$versions.load(on: database)
                    .flatMap {
                        if stage == .ingestion && pkg.status == .new {
                            // newly ingested package: leave status == .new for fast-track
                            // analysis
                        } else {
                            pkg.status = .ok
                        }
                        pkg.processingStage = stage
                        pkg.score = Score.compute(package: jpr, versions: pkg.versions)
                        return pkg.update(on: database)
                    }
                    .flatMapError { error in
                        logger.report(error: error)
                        return Current.reportError(client, .critical, error)
                            .flatMap { database.eventLoop.future(error: error) }
                    }
            case .failure(let error) where error as? PostgresNIO.PostgresError != nil:
                // Escalate database errors to critical
                return Current.reportError(client, .critical, error)
                    .flatMap { recordError(database: database, error: error, stage: stage) }
            case .failure(let error):
                return Current.reportError(client, .error, error)
                    .flatMap { recordError(database: database, error: error, stage: stage) }
        }
    }
    logger.debug("updateStatus ops: \(updates.count)")
    return EventLoopFuture.andAllComplete(updates, on: database.eventLoop)
}


func recordError(database: Database,
                 error: Error,
                 stage: Package.ProcessingStage) -> EventLoopFuture<Void> {
    func setStatus(id: Package.Id?, status: Package.Status) -> EventLoopFuture<Void> {
        guard let id = id else { return database.eventLoop.future() }
        return Package.query(on: database)
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

    guard let error = error as? AppError else { return database.eventLoop.future() }
    
    switch error {
        case let .analysisError(id, _):
            return setStatus(id: id, status: .analysisFailed)
        case .envVariableNotSet, .shellCommandFailed:
            return database.eventLoop.future()
        case let .genericError(id, _):
            return setStatus(id: id, status: .ingestionFailed)
        case let .invalidPackageCachePath(id, _):
            return setStatus(id: id, status: .invalidCachePath)
        case let .cacheDirectoryDoesNotExist(id, _):
            return setStatus(id: id, status: .cacheDirectoryDoesNotExist)
        case let .invalidPackageUrl(id, _):
            return setStatus(id: id, status: .invalidUrl)
        case let .invalidRevision(id, _):
            return setStatus(id: id, status: .analysisFailed)
        case let .metadataRequestFailed(id, _, _):
            return setStatus(id: id, status: .metadataRequestFailed)
        case let .noValidVersions(id, _):
            return setStatus(id: id, status: .noValidVersions)
    }
}
