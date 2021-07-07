import Fluent
import Plot
import Vapor


struct KeywordController {

    static func query(on database: Database, keyword: String, page: Int, pageSize: Int) -> EventLoopFuture<[Package]> {
        // page is one-based, clamp it to ensure we get a >=0 offset
        let page = page.clamped(to: 1...)
        let offset = (page - 1) * pageSize
        let limit = pageSize + 1  // fetch one more so we can determine `hasMoreResults`

        return Package.query(on: database)
            .with(\.$repositories)
            .join(Repository.self, on: \Repository.$package.$id == \Package.$id)
            .filter(
                DatabaseQuery.Field.path(Repository.path(for: \.$keywords), schema: Repository.schema),
                DatabaseQuery.Filter.Method.custom("@>"),
                DatabaseQuery.Value.bind([keyword])
            )
            .offset(offset)
            .limit(limit)
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
        let pageSize = Constants.resultsPageSize

        return Self.query(on: req.db, keyword: keyword, page: page, pageSize: pageSize)
            .map {
                $0.sorted(by: { $0.score ?? 0 > $1.score ?? 0 })
            }
            .map {
                $0.compactMap { PackageInfo(package: $0) }
            }
            .map { packages in
                KeywordShow.Model(
                    keyword: keyword,
                    packages: Array(packages.prefix(pageSize)),
                    page: page,
                    hasMoreResults: packages.count > pageSize
                )
            }
            .map {
                KeywordShow.View(path: req.url.path, model: $0).document()
            }
    }

}
