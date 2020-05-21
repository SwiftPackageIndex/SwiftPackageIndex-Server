import Fluent
import Plot
import Vapor

struct PackageController {

    func index(req: Request) throws -> EventLoopFuture<Response> {
        // No such thing as a full index of packages.
        return req.eventLoop.future(req.redirect(to: "/"))
    }

    func show(req: Request) throws -> EventLoopFuture<HTML> {
        guard let id = req.parameters.get("id").flatMap(UUID.init(uuidString:)) else {
            return req.eventLoop.future(error: Abort(.notFound))
        }
        return PackageShow.View.Model.query(database: req.db, packageId: id)
            .map { PackageShow.View($0).document() }
    }

}
