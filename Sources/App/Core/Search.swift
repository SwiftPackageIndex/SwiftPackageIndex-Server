import Fluent
import SQLKit
import Vapor


enum Search {
    static let schema = "search"

    struct Result: Content, Equatable {
        let hasMoreResults: Bool
        let results: [Search.Record]
    }

    struct Record: Content, Equatable {
        let packageId: Package.Id
        let packageName: String?
        let repositoryName: String?
        let repositoryOwner: String?
        let summary: String?
    }

    private struct DBRecord: Content, Equatable {
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
            case summary
        }

        var asRecord: Record {
            .init(packageId: packageId,
                  packageName: packageName,
                  repositoryName: repositoryName,
                  repositoryOwner: repositoryOwner,
                  summary: summary)
        }
    }
    
    private static func query(_ db: SQLDatabase, _ terms: [String]) -> EventLoopFuture<[DBRecord]> {
        let maxSearchTerms = 20  // just to impose some sort of limit
        let binds = terms[..<min(terms.count, maxSearchTerms)].map(SQLBind.init)
        let empty = SQLLiteral.string("")
        let space = SQLLiteral.string(" ")

        let packageName = SQLIdentifier("package_name")
        let repoName = SQLIdentifier("name")
        let repoOwner = SQLIdentifier("owner")
        let summary = SQLFunction("coalesce", args: SQLIdentifier("summary"), empty)
        let contains = SQLRaw("~*")
        let concat = SQLFunction("concat",
                                 args: packageName, space, summary, space, repoName, space, repoOwner)

        let preamble = db
            .select()
            .column("id")
            .column("package_name")
            .column("name")
            .column("owner")
            .column("summary")
            .from("search")

        return binds.reduce(preamble) { $0.where(concat, contains, $1) }
            .orderBy(SQLOrderBy(expression: SQLIdentifier("score"), direction: SQLDirection.descending))
            .limit(Constants.searchLimit + Constants.searchLimitLeeway)
            .all(decoding: DBRecord.self)
    }

    static func run(_ database: Database, _ terms: [String]) -> EventLoopFuture<Search.Result> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        return query(db, terms)
            .mapEach(\.asRecord)
            .map { results in
                // allow for a little leeway so we don't cut off with just a few more records
                // available
                let hasMoreResults = results.count >= Constants.searchLimit + Constants.searchLimitLeeway
                let cutOff = hasMoreResults ? Constants.searchLimit : results.count
                return Search.Result(hasMoreResults: hasMoreResults,
                                     results: Array(results[..<cutOff]))
        }
    }

    static func refresh(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        return db.raw("REFRESH MATERIALIZED VIEW \(Self.schema)").run()
    }
}
