import Fluent
import Plot
import Vapor


struct SearchController {

    func show(req: Request) throws -> EventLoopFuture<HTML> {
        let query = req.query[String.self, at: "query"] ?? ""
        let page = req.query[Int.self, at: "page"] ?? 1
        return API.search(database: req.db,
                          query: query,
                          page: page,
                          pageSize: Constants.searchPageSize)
            .map { SearchShow.Model.init(page: page, query: query, result: $0) }
            .map { SearchShow.View.init(path: req.url.path, model: $0).document() }
    }

}
