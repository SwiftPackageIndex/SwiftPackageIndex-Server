import Fluent
import Vapor


func updateStatus(application: Application,
                  results: [Result<Package, Error>],
                  stage: ProcessingStage) -> EventLoopFuture<Void> {
    let updates = results.map { result -> EventLoopFuture<Void> in
        switch result {
            case .success(let pkg):
                guard let pkgId = pkg.id else {
                    return application.db.eventLoop.future(error:
                        AppError.genericError(nil, "updateStatus: pkgId nil for package \(pkg.url)")
                    )
                }
                return Package.query(on: application.db)
                    .with(\.$repositories)
                    .with(\.$versions)
                    .filter(\.$id == pkgId)
                    .first()
                    .unwrap(or: AppError.genericError(pkg.id, "updateStatus: Package not found"))
                    .flatMap { pkg -> EventLoopFuture<Void> in
                        pkg.status = .ok
                        pkg.processingStage = stage
                        pkg.score = pkg.computeScore()
                        return pkg.update(on: application.db)
                }
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
                 stage: ProcessingStage) -> EventLoopFuture<Void> {
    func setStatus(id: Package.Id?, status: Status) -> EventLoopFuture<Void> {
        guard let id = id else { return database.eventLoop.future() }
        return Package.query(on: database)
            .filter(\.$id == id)
            .set(\.$processingStage, to: stage)
            .set(\.$status, to: status)
            .update()

    }

    database.logger.error("\(stage) error: \(error.localizedDescription)")

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
