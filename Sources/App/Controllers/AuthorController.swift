import Fluent
import Plot
import Vapor


struct AuthorController {

    private func query(on database: Database, owner: String) -> EventLoopFuture<[Package]> {
        Package.query(on: database)
            .with(\.$repositories)
            .join(Repository.self, on: \Repository.$package.$id == \Package.$id)
            .filter(
                DatabaseQuery.Field.path(Repository.path(for: \.$owner), schema: Repository.schema),
                DatabaseQuery.Filter.Method.custom("ilike"),
                DatabaseQuery.Value.bind(owner)
            )
            .all()
            .flatMapThrowing {
                if $0.isEmpty {
                    throw Abort(.notFound)
                }
                
                return $0
            }
    }

    func show(req: Request) throws -> EventLoopFuture<HTML> {
        guard let owner = req.parameters.get("owner") else {
            return req.eventLoop.future(error: Abort(.notFound))
        }

        return query(on: req.db, owner: owner)
            .map {
                AuthorShow.Model(
                    owner: $0.first?.repository?.owner ?? owner,
                    packages: $0.sorted(by: { $0.score ?? 0 > $1.score ?? 0 })
                                .compactMap { AuthorShow.PackageInfo(package: $0) }
                )
            }
            .map {
                AuthorShow.View(path: req.url.path, model: $0).document()
            }
    }

}
