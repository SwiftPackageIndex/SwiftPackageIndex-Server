import Fluent
import SQLKit
import Vapor


extension API {
    struct SearchController {
        static func get(req: Request) throws -> EventLoopFuture<[SearchQuery.Record]> {
            let query = req.query[String.self, at: "query"] ?? ""
            return search(database: req.db, query: query)
        }
    }
}


extension API {
    static func search(database: Database,
                       query: String) -> EventLoopFuture<[SearchQuery.Record]> {
        let terms = query.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard !terms.isEmpty else { return database.eventLoop.future([]) }
        return SearchQuery.run(database, terms)
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
            ([preamble] + terms.map(regexClause)).joined(separator: "\nand ")
        }

        static func run(_ database: Database, _ terms: [String]) -> EventLoopFuture<[API.SearchQuery.Record]> {
            guard let db = database as? SQLDatabase else {
                fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
            }
            return db.raw(.init(build(terms))).all(decoding: Record.self)
        }
    }
}
