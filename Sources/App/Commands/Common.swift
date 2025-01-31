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
import PostgresKit
import Vapor


// TODO: Adopt ProcessingError also in Analysis and then factor out generic parts back into Common
protocol ProcessingError: Error, CustomStringConvertible {
    associatedtype UnderlyingError: Error & CustomStringConvertible
    var packageId: Package.Id { get }
    var underlyingError: UnderlyingError { get }
    var level: Logger.Level { get }
    var status: Package.Status { get }
}


// TODO: Leaving this extension here for now in order to group the updating/error reporting in one place for both Ingestion and Analysis. Eventually these should either go to their respective files or move common parts into a Common namespace.
extension Analyze {
    /// Update packages (in the `[Result<Joined<Package, Repository>, Error>]` array).
    ///
    /// - Parameters:
    ///   - client: `Client` object
    ///   - database: `Database` object
    ///   - results: `Joined<Package, Repository>` results to update
    ///   - stage: Processing stage
    static func updatePackages(client: Client,
                               database: Database,
                               results: [Result<Joined<Package, Repository>, Error>]) async throws {
        @Dependency(\.logger) var logger
        do {
            let total = results.count
            let errors = results.filter(\.isError).count
            let errorRate = total > 0 ? 100.0 * Double(errors) / Double(total) : 0.0
            switch errorRate {
                case 0:
                    logger.info("Updating \(total) packages for stage 'analysis'")
                case 0..<20:
                    logger.info("Updating \(total) packages for stage 'analysis' (errors: \(errors))")
                default:
                    logger.critical("updatePackages: unusually high error rate: \(errors)/\(total) = \(errorRate)%")
            }
        }
        for result in results {
            do {
                try await updatePackage(client: client, database: database, result: result)
            } catch {
                logger.critical("updatePackage failed: \(error)")
            }
        }

        logger.debug("updateStatus ops: \(results.count)")
    }

    static func updatePackage(client: Client,
                              database: Database,
                              result: Result<Joined<Package, Repository>, Error>) async throws {
        @Dependency(\.logger) var logger
        switch result {
            case .success(let res):
                try await res.package.update(on: database, status: .ok, stage: .analysis)

                // PSQLError also conforms to DatabaseError but we want to intercept it specifically,
                // because it allows us to log more concise error messages via serverInfo[.message]
            case let .failure(error) where error is PSQLError:
                // Escalate database errors to critical
                let error = error as! PSQLError
                let msg = error.serverInfo?[.message] ?? String(reflecting: error)
                logger.critical("\(msg)")
                try await recordError(database: database, error: error)

            case let .failure(error) where error is DatabaseError:
                // Escalate database errors to critical
                logger.critical("\(String(reflecting: error))")
                try await recordError(database: database, error: error)

            case let .failure(error):
                logger.report(error: error)
                try await recordError(database: database, error: error)
        }
    }

    static func recordError(database: Database, error: Error) async throws {
        func setStatus(id: Package.Id?, status: Package.Status) async throws {
            guard let id = id else { return }
            try await Package.query(on: database)
                .filter(\.$id == id)
                .set(\.$processingStage, to: .analysis)
                .set(\.$status, to: status)
                .update()
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
            case let .invalidRevision(id, _):
                try await setStatus(id: id, status: .analysisFailed)
            case let .noValidVersions(id, _):
                try await setStatus(id: id, status: .noValidVersions)
        }
    }
}


// TODO: Leaving this extension here for now in order to group the updating/error reporting in one place for both Ingestion and Analysis. Eventually these should either go to their respective files or move common parts into a Common namespace.
extension Ingestion {
    static func updatePackage(client: Client,
                              database: Database,
                              result: Result<Joined<Package, Repository>, Ingestion.Error>,
                              stage: Package.ProcessingStage) async throws {
        @Dependency(\.logger) var logger
        switch result {
            case .success(let res):
                // for newly ingested package leave status == .new in order to fast-track analysis
                let updatedStatus: Package.Status = res.package.status == .new ? .new : .ok
                try await res.package.update(on: database, status: updatedStatus, stage: stage)
            case .failure(let failure):
                logger.log(level: failure.level, "\(failure)")
                try await Package.update(for: failure.packageId, on: database, status: failure.status, stage: stage)
        }
    }
}
