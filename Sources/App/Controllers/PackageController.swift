import Fluent
import Vapor

struct PackageController {

    func index(req: Request) throws -> EventLoopFuture<[Package]> {
        return Package.query(on: req.db)
            .all()
    }

    func get(req: Request) throws -> EventLoopFuture<Package> {
        return Package.find(req.parameters.get("id"), on: req.db)
            .unwrap(or: Abort(.notFound))
    }

}
