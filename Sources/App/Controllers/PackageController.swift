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
            .flatMap { package in
                // FIXME: temporary, for performance testing
                if let environment = try? Environment.detect(),
                   environment == .development,
                   (req.query[Int.self, at: "readme"] ?? 1) == 1 {
                    return fetchReadme(client: req.client, package: package).map{ (package, $0) }
                }
                return req.eventLoop.future((package, nil))
            }
            .map(PackageShow.Model.init(package:readme:))
            .unwrap(or: Abort(.notFound))
            .map { PackageShow.View(path: req.url.path, model: $0).document() }
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

}


private func fetchReadme(client: Client, package: Package) -> EventLoopFuture<String?> {
    guard let url = package.repository?.readmeUrl.map(URI.init(string:))
    else { return client.eventLoop.future(nil) }
    return client.get(url)
        .map { $0.body?.asString() }
}
