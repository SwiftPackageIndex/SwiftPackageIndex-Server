import Fluent
import Plot
import Vapor

struct PackageController {

    func index(req: Request) throws -> EventLoopFuture<Response> {
        // No such thing as a full index of packages.
        return req.eventLoop.future(req.redirect(to: "/"))
    }

    func show(req: Request) throws -> EventLoopFuture<HTML> {
        guard
            let owner = req.parameters.get("owner"),
            let repository = req.parameters.get("repository")
            else {
                return req.eventLoop.future(error: Abort(.notFound))
        }
        return PackageShow.Model.query(database: req.db, owner: owner, repository: repository)
            .map { PackageShow.View($0).document() }
    }

}
