import Fluent
import Plot
import Vapor

struct PackageController {

    func index(req: Request) throws -> EventLoopFuture<HTML> {
        return Package.query(on: req.db)
            .with(\.$repositories)
            .with(\.$versions)
            .sort(\.$updatedAt, .descending)
            .limit(10)
            .all()
            .map { packages in PackagesIndex(packages: packages).document() }
    }

    func get(req: Request) throws -> EventLoopFuture<Package> {
        return Package.find(req.parameters.get("id"), on: req.db)
            .unwrap(or: Abort(.notFound))
    }

}
