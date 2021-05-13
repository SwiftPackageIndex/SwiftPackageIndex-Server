import Fluent
import Plot
import Vapor

struct PackageController {
    
    func show(req: Request) throws -> EventLoopFuture<HTML> {
        guard
            let owner = req.parameters.get("owner"),
            let repository = req.parameters.get("repository")
        else {
            return req.eventLoop.future(error: Abort(.notFound))
        }
        return Package.query(on: req.db, owner: owner, repository: repository)
            .map(PackageShow.Model.init(package:))
            .unwrap(or: Abort(.notFound))
            .map { PackageShow.View(path: req.url.path, model: $0).document() }
    }

    func readme(req: Request) throws -> EventLoopFuture<Node<HTML.BodyContext>> {
        guard
            let owner = req.parameters.get("owner"),
            let repository = req.parameters.get("repository")
        else {
            return req.eventLoop.future(error: Abort(.notFound))
        }

        return Package.query(on: req.db, owner: owner, repository: repository)
            .flatMap { package in
                fetchReadme(client: req.client, package: package)
            }
            .map(PackageReadme.Model.init(readme:))
            .map { PackageReadme.View(model: $0).document() }
    }

    func builds(req: Request) throws -> EventLoopFuture<HTML> {
        guard
            let owner = req.parameters.get("owner"),
            let repository = req.parameters.get("repository")
        else {
            return req.eventLoop.future(error: Abort(.notFound))
        }
        return Package.query(on: req.db, owner: owner, repository: repository)
            .map(BuildIndex.Model.init(package:))
            .unwrap(or: Abort(.notFound))
            .map { BuildIndex.View(path: req.url.path, model: $0).document() }
    }

    func maintainerInfo(req: Request) throws -> EventLoopFuture<HTML> {
        guard
            let owner = req.parameters.get("owner"),
            let repository = req.parameters.get("repository")
        else {
            return req.eventLoop.future(error: Abort(.notFound))
        }

        return Package.query(on: req.db, owner: owner, repository: repository)
            .map(MaintainerInfoIndex.Model.init(package:))
            .unwrap(or: Abort(.notFound))
            .map { MaintainerInfoIndex.View(path: req.url.path, model: $0).document() }
    }
}


private func fetchReadme(client: Client, package: Package) -> EventLoopFuture<String?> {
    guard let url = package.repository?.readmeHtmlUrl.map(URI.init(string:))
    else { return client.eventLoop.future(nil) }
    return client.get(url).map { $0.body?.asString() }
}
