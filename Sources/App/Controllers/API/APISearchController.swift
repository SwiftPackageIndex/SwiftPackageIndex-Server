import Fluent
import Vapor


extension API {
    struct SearchController {
        static func get(req: Request) throws -> EventLoopFuture<[SearchResult]> {
            let query = req.query[String.self, at: "query"] ?? ""
            return search(database: req.db, query: query)
        }
    }
}


extension API {
    struct SearchResult: Content, Equatable {
        let packageName: String
        let repositoryId: String
        let summary: String
    }

    static func search(database: Database, query: String) -> EventLoopFuture<[API.SearchResult]> {
        let terms = query.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard !terms.isEmpty else { return database.eventLoop.future([]) }
        return database.eventLoop.future([
            .init(packageName: "FooBar", repositoryId: "someone/FooBar", summary: "A foo bar repo"),
            .init(packageName: "BazBaq", repositoryId: "another/barbaq", summary: "Some other repo"),
        ])
    }
}
