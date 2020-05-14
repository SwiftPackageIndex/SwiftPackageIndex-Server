import Fluent
import Plot
import Vapor

struct PackageController {

    func index(req: Request) throws -> EventLoopFuture<Response> {
        // No such thing as a full index of packages.
        return req.eventLoop.future(req.redirect(to: "/"))
    }

    func show(req: Request) throws -> EventLoopFuture<HTML> {
        return Package.find(req.parameters.get("id"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .map { package in PackageShowView(package).document() }
    }

}
