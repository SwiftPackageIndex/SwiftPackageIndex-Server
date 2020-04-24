import Fluent
import Vapor

struct PackageController {
    func index(req: Request) throws -> EventLoopFuture<[Package]> {
        return Package.query(on: req.db).all()
    }

    func create(req: Request) throws -> EventLoopFuture<Package> {
        let pkg = try req.content.decode(Package.self)
        return pkg.save(on: req.db).map { pkg }
    }

    func get(req: Request) throws -> EventLoopFuture<Package> {
        return Package.find(req.parameters.get("id"), on: req.db)
            .unwrap(or: Abort(.notFound))
    }

    func replace(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let pkg = try req.content.decode(Package.self)
        return Package.find(req.parameters.get("id"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { _ in pkg.save(on: req.db) }
            .transform(to: .ok)
    }

    func delete(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        return Package.find(req.parameters.get("id"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { $0.delete(on: req.db) }
            .transform(to: .ok)
    }
}
