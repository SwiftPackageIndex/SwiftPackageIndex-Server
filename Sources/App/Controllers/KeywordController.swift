import Fluent
import Plot
import Vapor


struct KeywordController {

    static func query(on database: Database, keyword: String) -> EventLoopFuture<[Package]> {
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
        let page = req.query[Int.self, at: "page"] ?? 1

        return Self.query(on: req.db, keyword: keyword)
            .map {
                $0.sorted(by: { $0.score ?? 0 > $1.score ?? 0 })
            }
            .map {
                $0.compactMap { PackageInfo(package: $0) }
            }
            .map { packages in
                // FIXME: move up into query
                let page = page.clamped(to: 1...)
                let offset = (page - 1) * Constants.resultsPageSize
                let limit = Constants.resultsPageSize + 1
                let packages = packages.dropFirst(offset).prefix(limit)
                return (packages: Array(packages.prefix(Constants.resultsPageSize)),
                        hasMoreResults: packages.count > Constants.resultsPageSize)
            }
            .map { packages, hasMoreResults in
                KeywordShow.Model(
                    keyword: keyword,
                    packages: packages,
                    page: page,
                    hasMoreResults: hasMoreResults
                )
            }
            .map {
                KeywordShow.View(path: req.url.path, model: $0).document()
            }
    }

}
