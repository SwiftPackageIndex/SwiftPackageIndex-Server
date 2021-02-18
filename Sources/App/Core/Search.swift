import Fluent
import SQLKit
import Vapor


enum Search {
    static let schema = "search"
    
    // identifiers
    static let id = SQLIdentifier("id")
    static let packageName = SQLIdentifier("package_name")
    static let repoName = SQLIdentifier("name")
    static let repoOwner = SQLIdentifier("owner")
    static let summary = SQLIdentifier("summary")
    static let score = SQLIdentifier("score")
    static let searchView = SQLIdentifier("search")
    
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
            return SiteURL.package(.value(owner), .value(name), .none).relativeURL()
        }
        
        var asRecord: Record {
            .init(packageId: packageId,
                  packageName: packageName,
                  packageURL: packageURL,
                  repositoryName: repositoryName,
                  repositoryOwner: repositoryOwner,
                  summary: summary?.replaceShorthandEmojis())
        }
    }
    
    static func query(_ database: Database,
                      _ terms: [String],
                      page: Int,
                      pageSize: Int) -> EventLoopFuture<Search.Result> {
        let offset = (page - 1) * pageSize
        guard offset >= 0 else {
            return database.eventLoop.future(error: AppError.genericError(nil, "page is one-based and must be greater than zero"))
        }

        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }

        let maxSearchTerms = 20  // just to impose some sort of limit
        
        // binds
        let mergedTerms = SQLBind(terms.joined(separator: " ").lowercased())
        let binds = terms[..<min(terms.count, maxSearchTerms)].map(SQLBind.init)
        
        // constants
        let empty = SQLLiteral.string("")
        let space = SQLLiteral.string(" ")
        let contains = SQLRaw("~*")
        
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
            .from(searchView)
        
        return binds.reduce(preamble) { $0.where(haystack, contains, $1) }
            .where(isNotNull(packageName))
            .where(isNotNull(repoOwner))
            .where(isNotNull(repoName))
            .orderBy(eq(lower(packageName), mergedTerms), .descending)
            .orderBy(score, SQLDirection.descending)
            .offset(offset)
            .limit(pageSize + 1)  // fetch one more so we can determine `hasMoreResults`
            .all(decoding: DBRecord.self)
            .mapEach(\.asRecord)
            .map { results in
                let hasMoreResults = results.count > pageSize
                return Search.Result(hasMoreResults: hasMoreResults,
                                     results: Array(results.prefix(pageSize)))
            }
    }
    
    static func refresh(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        return db.raw("REFRESH MATERIALIZED VIEW \(raw: Self.schema)").run()
    }
}


private extension SQLSelectBuilder {
    // sas 2020-06-05: workaround `direction: SQLExpression` signature in SQLKit
    // (should be SQLDirection)
    func orderBy(_ expression: SQLExpression, _ direction: SQLDirection = .ascending) -> Self {
        return self.orderBy(SQLOrderBy(expression: expression, direction: direction))
    }
}
