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
import PostgresKit
import Vapor


/// Update packages (in the `[Result<Joined<Package, Repository>, Error>]` array).
///
/// - Parameters:
///   - client: `Client` object
///   - database: `Database` object
///   - results: `Joined<Package, Repository>` results to update
///   - stage: Processing stage
func updatePackages(client: Client,
                    database: Database,
                    results: [Result<Joined<Package, Repository>, Error>],
                    stage: Package.ProcessingStage) async throws {
    do {
        let total = results.count
        let errors = results.filter(\.isError).count
        let errorRate = total > 0 ? 100.0 * Double(errors) / Double(total) : 0.0
        switch errorRate {
            case 0:
                Current.logger().info("Updating \(total) packages for stage '\(stage)'")
            case 0..<20:
                Current.logger().info("Updating \(total) packages for stage '\(stage)' (errors: \(errors))")
            default:
                Current.logger().critical("updatePackages: unusually high error rate: \(errors)/\(total) = \(errorRate)%")
        }
    }
    for result in results {
        do {
            try await updatePackage(client: client, database: database, result: result, stage: stage)
        } catch {
            Current.logger().critical("updatePackage failed: \(error)")
        }
    }

    Current.logger().debug("updateStatus ops: \(results.count)")
}


func updatePackage(client: Client,
                   database: Database,
                   result: Result<Joined<Package, Repository>, Error>,
                   stage: Package.ProcessingStage) async throws {
    switch result {
        case .success(let res):
            let pkg = res.package
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
                Current.logger().report(error: error)
            }

        // PSQLError also conforms to DatabaseError but we want to intercept it specifically,
        // because it allows us to log more concise error messages via serverInfo[.message]
        case let .failure(error) where error is PSQLError:
            // Escalate database errors to critical
            let error = error as! PSQLError
            let msg = error.serverInfo?[.message] ?? String(reflecting: error)
            Current.logger().critical("\(msg)")
            try await recordError(database: database, error: error, stage: stage)

        case let .failure(error) where error is DatabaseError:
            // Escalate database errors to critical
            Current.logger().critical("\(String(reflecting: error))")
            try await recordError(database: database, error: error, stage: stage)

        case let .failure(error):
            Current.logger().report(error: error)
            try await recordError(database: database, error: error, stage: stage)
    }
}


func updatePackage(client: Client,
                   database: Database,
                   result: Result<Joined<Package, Repository>, Ingestion.Error>,
                   stage: Package.ProcessingStage) async throws {
    switch result {
        case .success(let res):
            try await updatePackage(database: database, package: res.package, stage: stage)
        case .failure(let failure):
            switch failure.underlyingError {
                case .fetchMetadataFailed:
                    Current.logger().warning("\(failure)")

                case .findOrCreateRepositoryFailed:
                    Current.logger().critical("\(failure)")

                case .invalidURL, .noRepositoryMetadata:
                    Current.logger().warning("\(failure)")

                case .repositorySaveFailed, .repositorySaveUniqueViolation:
                    Current.logger().critical("\(failure)")
            }

            try await recordIngestionError(database: database, error: failure)
    }
}


func updatePackage(database: Database,
                   package: Package,
                   stage: Package.ProcessingStage) async throws {
    if stage == .ingestion && package.status == .new {
        // newly ingested package: leave status == .new for fast-track
        // analysis
    } else {
        package.status = .ok
    }
    package.processingStage = stage
    do {
        try await package.update(on: database)
    } catch {
        Current.logger().report(error: error)
    }
}


func recordError(database: Database,
                 error: Error,
                 stage: Package.ProcessingStage) async throws {
    if let error = error as? Ingestion.Error {
        try await recordIngestionError(database: database, error: error)
    } else {
        func setStatus(id: Package.Id?, status: Package.Status) async throws {
            guard let id = id else { return }
            try await Package.query(on: database)
                .filter(\.$id == id)
                .set(\.$processingStage, to: stage)
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


func recordIngestionError(database: Database, error: Ingestion.Error) async throws {
    switch error.underlyingError {
        case .fetchMetadataFailed, .findOrCreateRepositoryFailed, .noRepositoryMetadata, .repositorySaveFailed:
            try await Package
                .update(for: error.packageId, on: database, status: .ingestionFailed, stage: .ingestion)
        case .invalidURL:
            try await Package
                .update(for: error.packageId, on: database, status: .invalidUrl, stage: .ingestion)
        case .repositorySaveUniqueViolation:
            try await Package
                .update(for: error.packageId, on: database, status: .ingestionFailed, stage: .ingestion)
    }
}


extension Package {
#warning("Move")
    static func update(for id: Package.Id,
                       on database: Database,
                       status: Status,
                       stage: ProcessingStage) async throws {
        try await Package.query(on: database)
            .filter(\.$id == id)
            .set(\.$processingStage, to: stage)
            .set(\.$status, to: status)
            .update()
    }
}
