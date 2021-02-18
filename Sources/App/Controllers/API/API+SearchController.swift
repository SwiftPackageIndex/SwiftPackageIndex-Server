import Fluent
import Vapor


extension API {
    struct SearchController {
        static func get(req: Request) throws -> EventLoopFuture<Search.Result> {
            let query = req.query[String.self, at: "query"] ?? ""
            return search(database: req.db, query: query)
        }
    }
}


extension API {
    static func search(database: Database,
                       query: String,
                       page: Int = 1,
                       pageSize: Int = Constants.searchPageSize) -> EventLoopFuture<Search.Result> {
        let terms = query.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard !terms.isEmpty else {
            return database.eventLoop.future(.init(hasMoreResults: false, results: []))
        }
        return Search.run(database, terms, page: page, pageSize: pageSize)
    }
}
