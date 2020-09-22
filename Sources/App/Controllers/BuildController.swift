import Fluent
import Plot
import Vapor


struct BuildController {

    @available(*, deprecated)
    func _show(req: Request) throws -> EventLoopFuture<HTML> {
        guard let id = req.parameters.get("id"),
              let buildId = UUID.init(uuidString: id)
        else { return req.eventLoop.future(error: Abort(.notFound)) }

        return Build.query(on: req.db, buildId: buildId)
            .map(BuildShow.Model.init(build:))
            .unwrap(or: Abort(.notFound))
            .map {
                BuildShow.View(path: req.url.path, model: $0).document()
            }
    }

    func showS3(req: Request) throws -> EventLoopFuture<HTML> {
        guard let id = req.parameters.get("id"),
              let buildId = UUID.init(uuidString: id)
        else { return req.eventLoop.future(error: Abort(.notFound)) }

        return Build.query(on: req.db, buildId: buildId)
            .flatMap { build -> EventLoopFuture<(Build, String?)> in
                guard let logUrl = build.logUrl else {
                    return req.eventLoop.future((build, nil))
                }
                return req.client.get(URI(string: logUrl))
                    .map { $0.body?.asString() }
                    .map { (build, $0) }
            }
            .map(BuildShow.Model.init(build:logs:))
            .unwrap(or: Abort(.notFound))
            .map {
                BuildShow.View(path: req.url.path, model: $0).document()
            }
    }

}
