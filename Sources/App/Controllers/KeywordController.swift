import Fluent
import Plot
import Vapor


struct KeywordController {

    private func query(on database: Database, keyword: String) -> EventLoopFuture<[Package]> {
        Package.query(on: database)
            .with(\.$repositories)
            .join(Repository.self, on: \Repository.$package.$id == \Package.$id)
            .filter(
                DatabaseQuery.Field.path(Repository.path(for: \.$keywords), schema: Repository.schema),
                DatabaseQuery.Filter.Method.custom("@>"),
                DatabaseQuery.Value.bind([keyword])
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
        guard let keyword = req.parameters.get("keyword") else {
            return req.eventLoop.future(error: Abort(.notFound))
        }

        return query(on: req.db, keyword: keyword)
            .map {
                KeywordShow.Model(
                    keyword: keyword,
                    packages: $0.sorted(by: { $0.score ?? 0 > $1.score ?? 0 })
                                .compactMap { PackageInfo(package: $0) }
                )
            }
            .map {
                KeywordShow.View(path: req.url.path, model: $0).document()
            }
    }

}
