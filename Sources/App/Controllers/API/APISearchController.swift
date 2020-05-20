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

    static func search(database: Database, query: String) -> EventLoopFuture<[API.SearchResult]> {
        let terms = query.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard !terms.isEmpty else { return database.eventLoop.future([]) }
        return database.eventLoop.future([
            .init(packageId: UUID(uuidString: "442cf59f-0135-4d08-be00-bc9a7cebabd3")!,
                  packageName: "FooBar",
                  repositoryName: "someone",
                  repositoryOwner: "FooBar",
                  summary: "A foo bar repo"),
            .init(packageId: UUID(uuidString: "4e256250-d1ea-4cdd-9fe9-0fc5dce17a80")!,
                  packageName: "BazBaq",
                  repositoryName: "another",
                  repositoryOwner: "barbaq",
                  summary: "Some other repo"),
        ])
    }

    enum SearchQuery {
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

        static func buildQuery(_ terms: [String]) -> String {
            ([preamble] + terms.map(regexClause)).joined(separator: "\nand ")
        }

        static func run(_ database: Database, _ terms: [String]) -> EventLoopFuture<[API.SearchResult]> {
            guard let db = database as? SQLDatabase else {
                fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
            }
            return db.raw(.init(buildQuery(terms))).all(decoding: SearchResult.self)
        }
    }
}
