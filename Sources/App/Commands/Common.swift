import Fluent
import PostgresNIO
import Vapor


func updatePackages(application: Application,
                    results: [Result<Package, Error>],
                    stage: Package.ProcessingStage) -> EventLoopFuture<Void> {
    let updates = results.map { result -> EventLoopFuture<Void> in
        switch result {
            case .success(let pkg):
                return pkg.$repositories
                    .load(on: application.db)
                    .flatMap { pkg.$versions.load(on: application.db) }
                    .flatMap {
                        if stage == .ingestion && pkg.status == .new {
                            // newly ingested package: leave status == .new for fast-track
                            // analysis
                        } else {
                            pkg.status = .ok
                        }
                        pkg.processingStage = stage
                        pkg.score = pkg.computeScore()
                        return pkg.update(on: application.db)
                    }
                    .flatMapError { error in
                        application.logger.report(error: error)
                        return Current.reportError(application.client, .critical, error)
                            .flatMap { application.eventLoopGroup.next().future(error: error) }
                    }
            case .failure(let error) where error as? PostgresNIO.PostgresError != nil:
                // Escalate database errors to critical
                return Current.reportError(application.client, .critical, error)
                    .flatMap { recordError(database: application.db, error: error, stage: stage) }
            case .failure(let error):
                return Current.reportError(application.client, .error, error)
                    .flatMap { recordError(database: application.db, error: error, stage: stage) }
        }
    }
    application.logger.debug("updateStatus ops: \(updates.count)")
    return EventLoopFuture.andAllComplete(updates, on: application.eventLoopGroup.next())
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
    
    database.logger.error("\(stage) error: \(error)")
    
    guard let error = error as? AppError else { return database.eventLoop.future() }
    
    switch error {
        case .envVariableNotSet, .shellCommandFailed:
            return database.eventLoop.future()
        case let .genericError(id, _):
            return setStatus(id: id, status: .ingestionFailed)
        case let .invalidPackageCachePath(id, _):
            return setStatus(id: id, status: .invalidCachePath)
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
