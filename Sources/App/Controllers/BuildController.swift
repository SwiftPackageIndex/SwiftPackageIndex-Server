import Fluent
import Plot
import Vapor


struct BuildController {

    func show(req: Request) throws -> EventLoopFuture<HTML> {
        guard let id = req.parameters.get("id"),
              let buildId = UUID.init(uuidString: id)
        else { return req.eventLoop.future(error: Abort(.notFound)) }

        return Build.query(on: req.db, buildId: buildId)
            .flatMap { build in
                Build.fetchLogs(client: req.client, logUrl: build.logUrl)
                    .map { (build, $0) }
            }
            .map(BuildShow.Model.init(build:logs:))
            .unwrap(or: Abort(.notFound))
            .map {
                BuildShow.View(path: req.url.path, model: $0).document()
            }
    }

}
