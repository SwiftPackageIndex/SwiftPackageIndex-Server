import Fluent
import SQLKit
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
//        let packageId: Package.Id
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

    enum SearchQuery {
        static var preamble: String {
            """
            select
            v.package_name
            --, r.summary, r.name, r.owner
            from packages p
            join repositories r on r.package_id = p.id
            join versions v on v.package_id = p.id
            where v.reference ->> 'branch' = r.default_branch
            """
        }

        static func regexClause(_ term: String) -> String {
            "coalesce(v.package_name) || ' ' || coalesce(r.summary, '') || ' ' || coalesce(r.name, '') || ' ' || coalesce(r.owner, '') ~* '\(term)'"
        }

        static func buildQuery(_ terms: [String]) -> String {
            ([preamble] + terms.map(regexClause)).joined(separator: "\nand ")
        }
    }
}
