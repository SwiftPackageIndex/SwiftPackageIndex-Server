import Fluent
import SQLKit
import Vapor


enum Search {
    static let schema = "search"

    struct Result: Content, Equatable {
        var hasMoreResults: Bool
        var results: [Search.Record]
    }

    struct Record: Content, Equatable {
        var packageId: Package.Id
        var packageName: String?
        var packageURL: String?
        var repositoryName: String?
        var repositoryOwner: String?
        var summary: String?
    }

    struct DBRecord: Content, Equatable {
        var packageId: Package.Id
        var packageName: String?
        var repositoryName: String?
        var repositoryOwner: String?
        var summary: String?

        enum CodingKeys: String, CodingKey {
            case packageId = "id"
            case packageName = "package_name"
            case repositoryName = "name"
            case repositoryOwner = "owner"
            case summary
        }

        var packageURL: String? {
            guard
                let owner = repositoryOwner,
                let name = repositoryName
                else { return nil }
            return SiteURL.package(.value(owner), .value(name)).relativeURL
        }

        var asRecord: Record {
            .init(packageId: packageId,
                  packageName: packageName,
                  packageURL: packageURL,
                  repositoryName: repositoryName,
                  repositoryOwner: repositoryOwner,
                  summary: summary)
        }
    }
    
    private static func query(_ db: SQLDatabase, _ terms: [String]) -> EventLoopFuture<[DBRecord]> {
        let maxSearchTerms = 20  // just to impose some sort of limit

        // binds
        let mergedTerms = SQLBind(terms.joined(separator: " ").lowercased())
        let binds = terms[..<min(terms.count, maxSearchTerms)].map(SQLBind.init)

        // constants
        let empty = SQLLiteral.string("")
        let space = SQLLiteral.string(" ")
        let contains = SQLRaw("~*")

        // identifiers
        let id = SQLIdentifier("id")
        let packageName = SQLIdentifier("package_name")
        let repoName = SQLIdentifier("name")
        let repoOwner = SQLIdentifier("owner")
        let summary = SQLIdentifier("summary")
        let score = SQLIdentifier("score")
        let search = SQLIdentifier("search")

        let haystack = concat(
            packageName, space, coalesce(summary, empty), space, repoName, space, repoOwner
        )

        let preamble = db
            .select()
            .column(id)
            .column(packageName)
            .column(repoName)
            .column(repoOwner)
            .column(summary)
            .from(search)

        return binds.reduce(preamble) { $0.where(haystack, contains, $1) }
            .where(isNotNull(packageName))
            .where(isNotNull(repoOwner))
            .where(isNotNull(repoName))
            .orderBy(eq(lower(packageName), mergedTerms), .descending)
            .orderBy(score, SQLDirection.descending)
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


private func concat(_ args: SQLExpression...) -> SQLFunction {
    SQLFunction("concat", args: args)
}


private func coalesce(_ args: SQLExpression...) -> SQLFunction {
    SQLFunction("coalesce", args: args)
}


private func lower(_ arg: SQLExpression) -> SQLFunction {
    SQLFunction("lower", args: arg)
}


private func isNotNull(_ column: SQLIdentifier) -> SQLBinaryExpression {
    SQLBinaryExpression(left: column, op: SQLBinaryOperator.isNot, right: SQLRaw("NULL"))
}


private func eq(_ lhs: SQLExpression, _ rhs: SQLExpression) -> SQLBinaryExpression {
    SQLBinaryExpression(left: lhs, op: SQLBinaryOperator.equal, right: rhs)
}


private extension SQLSelectBuilder {
    // sas 2020-06-05: workaround `direction: SQLExpression` signature in SQLKit
    // (should be SQLDirection)
    func orderBy(_ expression: SQLExpression, _ direction: SQLDirection = .ascending) -> Self {
        return self.orderBy(SQLOrderBy(expression: expression, direction: direction))
    }
}
