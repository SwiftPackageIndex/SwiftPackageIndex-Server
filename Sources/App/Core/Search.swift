import Fluent
import SQLKit
import Vapor


enum Search {
    static let schema = "search"
    
    // identifiers
    static let keyword = SQLIdentifier("keyword")
    static let keywords = SQLIdentifier("keywords")
    static let packageId = SQLIdentifier("package_id")
    static let packageName = SQLIdentifier("package_name")
    static let repoName = SQLIdentifier("repo_name")
    static let repoOwner = SQLIdentifier("repo_owner")
    static let score = SQLIdentifier("score")
    static let searchView = SQLIdentifier("search")
    static let summary = SQLIdentifier("summary")

    static let null = SQLRaw("NULL")

    enum MatchType: String, Codable, Equatable {
        case package
        case keyword

        static let identifier = SQLIdentifier(DBRecord.CodingKeys.matchType.rawValue)

        var literal: SQLRaw {
            SQLRaw("'\(rawValue)'")
        }

        var sqlAlias: SQLAlias {
            SQLAlias(literal,as: Self.identifier)
        }

        static func equals(_ value: MatchType) -> SQLExpression {
            eq(MatchType.identifier, value.literal)
        }
    }

    struct Response: Content, Equatable {
        var hasMoreResults: Bool
        var results: [Search.Result]
    }

    struct DBRecord: Content, Equatable {
        var matchType: MatchType
        var keyword: String?
        var packageId: Package.Id?
        var packageName: String?
        var repositoryName: String?
        var repositoryOwner: String?
        var summary: String?
        
        enum CodingKeys: String, CodingKey {
            case matchType = "match_type"
            case keyword
            case packageId = "package_id"
            case packageName = "package_name"
            case repositoryName = "repo_name"
            case repositoryOwner = "repo_owner"
            case summary
        }
        
        var packageURL: String? {
            guard
                let owner = repositoryOwner,
                let name = repositoryName
            else { return nil }
            return SiteURL.package(.value(owner), .value(name), .none).relativeURL()
        }
    }

    static func sanitize(_ terms: [String]) -> [String] {
        terms
            .map { $0.replacingOccurrences(of: "*", with: "\\*") }
            .map { $0.replacingOccurrences(of: "?", with: "\\?") }
            .map { $0.replacingOccurrences(of: "(", with: "\\(") }
            .map { $0.replacingOccurrences(of: ")", with: "\\)") }
            .map { $0.replacingOccurrences(of: "[", with: "\\[") }
            .map { $0.replacingOccurrences(of: "]", with: "\\]") }
            .filter { !$0.isEmpty }
    }

    static func packageMatchQueryBuilder(on database: Database,
                                         terms: [String],
                                         offset: Int? = nil,
                                         limit: Int? = nil) -> SQLSelectBuilder {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }

        let maxSearchTerms = 20  // just to impose some sort of limit

        // binds
        let binds = terms[..<min(terms.count, maxSearchTerms)].map(SQLBind.init)

        // constants
        let empty = SQLLiteral.string("")
        let contains = SQLRaw("~*")

        let haystack = concat(
            with: " ",
            packageName, coalesce(summary, empty), repoName, repoOwner
        )

        let preamble = db
            .select()
            .column(.package)
            .column(null, as: keyword)
            .column(packageId)
            .column(packageName)
            .column(repoName)
            .column(repoOwner)
            .column(score)
            .column(summary)
            .from(searchView)

        return binds.reduce(preamble) { $0.where(haystack, contains, $1) }
            .where(isNotNull(packageName))
            .where(isNotNull(repoOwner))
            .where(isNotNull(repoName))
            .offset(offset)
            .limit(limit)
    }

    static func keywordMatchQueryBuilder(on database: Database,
                                         terms: [String]) -> SQLSelectBuilder {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        let mergedTerms = SQLBind(terms.joined(separator: " ").lowercased())
        // FIXME: bookend with `%`

        return db
            .select()
            .column(.keyword)
            .column(keyword)
            .column(null, as: packageId)
            .column(null, as: packageName)
            .column(null, as: repoName)
            .column(null, as: repoOwner)
            .column(null, as: score)
            .column(null, as: summary)
            .from(searchView)
            .from(SQLFunction("UNNEST", args: keywords), as: keyword)
            .where(keyword, .equal, mergedTerms)
            .limit(1)
        // TODO: increase limit when we do % matching
    }

    static func query(_ database: Database,
                      _ terms: [String],
                      page: Int,
                      pageSize: Int) -> SQLSelectBuilder? {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }

        let sanitizedTerms = sanitize(terms)
        guard !sanitizedTerms.isEmpty else {
            return nil
        }
        let mergedTerms = SQLBind(sanitizedTerms.joined(separator: " ").lowercased())

        // page is one-based, clamp it to 0-based offset
        let offset = ((page - 1) * pageSize).clamped(to: 0...)
        let limit = pageSize + 1  // fetch one more so we can determine `hasMoreResults`

        let union = db.unionAll(
            keywordMatchQueryBuilder(on: database, terms: sanitizedTerms),
            packageMatchQueryBuilder(on: database, terms: sanitizedTerms,
                                     offset: offset, limit: limit)
        )
        let packageOrder = SQLOrderBy(eq(lower(packageName), mergedTerms),
                                      .descending)
            .then(score, .descending)
            .then(packageName, .ascending)

        return db.select()
            .column("*")
            .from(
                SQLAlias(SQLGroupExpression(union.query), as: SQLIdentifier("t"))
            )
            .orderBy(SQLOrderBy(MatchType.equals(.keyword), .descending))
            .orderBy(SQLOrderBy(MatchType.equals(.package), .descending))
            .orderBy(packageOrder)
    }

    static func fetch(_ database: Database,
                      _ terms: [String],
                      page: Int,
                      pageSize: Int) -> EventLoopFuture<Search.Response> {
        guard let query = query(database,
                                terms,
                                page: page,
                                pageSize: pageSize) else {
            return database.eventLoop.future(.init(hasMoreResults: false,
                                                   results: []))
        }
        return query.all(decoding: DBRecord.self)
            .mapEachCompact(Result.init)
            .map { results in
                let hasMoreResults = results.count > pageSize
                return Search.Response(hasMoreResults: hasMoreResults,
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
