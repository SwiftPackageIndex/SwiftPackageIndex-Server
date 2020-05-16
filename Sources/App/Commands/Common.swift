import Fluent
import Vapor


func updateStatus(application: Application,
                  results: [Result<Package, Error>],
                  stage: ProcessingStage) -> EventLoopFuture<Void> {
    let updates = results.map { result -> EventLoopFuture<Void> in
        switch result {
            case .success(let pkg):
                pkg.status = .ok
                pkg.processingStage = stage
                return pkg.update(on: application.db)
            case .failure(let error):
                return recordError(client: application.client,
                                   database: application.db,
                                   error: error,
                                   stage: stage)
        }
    }
    application.logger.debug("updateStatus ops: \(updates.count)")
    return EventLoopFuture.andAllComplete(updates, on: application.eventLoopGroup.next())
}


// TODO: sas: 2020-05-15: clean this up
// https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/69
func recordError(client: Client,
                 database: Database,
                 error: Error,
                 stage: ProcessingStage) -> EventLoopFuture<Void> {
    let errorReport = Current.reportError(client, .error, error)

    func setStatus(id: Package.Id?, status: Status) -> EventLoopFuture<Void> {
        guard let id = id else { return database.eventLoop.future() }
        return Package.query(on: database)
            .filter(\.$id == id)
            .set(\.$processingStage, to: stage)
            .set(\.$status, to: status)
            .update()

    }

    database.logger.error("\(stage) error: \(error.localizedDescription)")

    guard let error = error as? AppError else { return errorReport }
    switch error {
        case .envVariableNotSet:
            break
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

    return errorReport
}
