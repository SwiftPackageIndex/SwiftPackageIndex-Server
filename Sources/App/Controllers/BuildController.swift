import Fluent
import Plot
import Vapor


struct BuildController {

    func show(req: Request) throws -> EventLoopFuture<HTML> {
        guard let id = req.parameters.get("id"),
              let buildId = UUID.init(uuidString: id)
        else { return req.eventLoop.future(error: Abort(.notFound)) }

        return Build.find(buildId, on: req.db)
            .unwrap(or: Abort(.notFound))
            .map(BuildShow.Model.init(build:))
            .map {
                BuildShow.View(path: req.url.path, model: $0).document()
            }
    }

}
