import Fluent
import Plot
import Vapor


struct SearchController {

    func show(req: Request) throws -> EventLoopFuture<HTML> {
        let query = req.query[String.self, at: "query"] ?? ""
        return API.search(database: req.db, query: query)
            .map(\.results)
            .map { Search.Model.init(query: query, results: $0) }
            .map { Search.View.init(path: req.url.path, model: $0).document() }
    }

}
