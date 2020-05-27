import Fluent
import SQLKit
import Vapor


extension API {
    struct SearchController {
        static func get(req: Request) throws -> EventLoopFuture<SearchResult> {
            let query = req.query[String.self, at: "query"] ?? ""
            return search(database: req.db, query: query)
        }
    }
}


extension API {
    static func search(database: Database,
                       query: String) -> EventLoopFuture<SearchResult> {
        let terms = query.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard !terms.isEmpty else {
            return database.eventLoop.future(.init(hasMoreResults: false, results: []))
        }
        return SearchQuery.run(database, terms)
    }

    struct SearchResult: Content, Equatable {
        let hasMoreResults: Bool
        let results: [SearchQuery.Record]
    }

    enum SearchQuery {
        struct Record: Content, Equatable {
            let packageId: Package.Id
            let packageName: String?
            let repositoryName: String?
            let repositoryOwner: String?
            let summary: String?

            enum CodingKeys: String, CodingKey {
                case packageId = "id"
                case packageName = "package_name"
                case repositoryName = "name"
                case repositoryOwner = "owner"
                case summary = "summary"
            }
        }

        static var preamble: String {
            """
            select
              p.id,
              v.package_name,
              r.name,
              r.owner,
              r.summary
            from packages p
              join repositories r on r.package_id = p.id
              join versions v on v.package_id = p.id
            where v.reference ->> 'branch' = r.default_branch
            """
        }

        static func regexClause(_ term: String) -> String {
            "coalesce(v.package_name) || ' ' || coalesce(r.summary, '') || ' ' || coalesce(r.name, '') || ' ' || coalesce(r.owner, '') ~* '\(term)'"
        }

        static func build(_ terms: [String]) -> String {
            ([preamble]
                + terms.map(regexClause)
                ).joined(separator: "\n  and ")
                + "\n  order by p.score desc"
                + "\n  limit \(Constants.searchLimit + Constants.searchLimitLeeway)"
        }

        static func run(_ database: Database, _ terms: [String]) -> EventLoopFuture<SearchResult> {
            guard let db = database as? SQLDatabase else {
                fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
            }
            return db.raw(.init(build(terms))).all(decoding: Record.self)
                .map { results in
                    // allow for a little leeway so we don't cut off with just a few more records
                    // available
                    let hasMoreResults = results.count >= Constants.searchLimit + Constants.searchLimitLeeway
                    let cutOff = hasMoreResults ? Constants.searchLimit : results.count
                    return SearchResult(hasMoreResults: hasMoreResults,
                                        results: Array(results[..<cutOff]))
            }
        }
    }
}
