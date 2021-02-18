import Fluent
import Plot
import Vapor


struct SearchController {

    func show(req: Request) throws -> EventLoopFuture<HTML> {
        let query = req.query[String.self, at: "query"] ?? ""
        let page = req.query[Int.self, at: "page"] ?? 1
        let pageSize = req.query[Int.self, at: "page-size"] ?? Constants.searchPageSize
        return API.search(database: req.db,
                          query: query,
                          page: page,
                          pageSize: pageSize)
            .map(\.results)
            .map { SearchShow.Model.init(query: query, results: $0) }
            .map { SearchShow.View.init(path: req.url.path, model: $0).document() }
    }

}
