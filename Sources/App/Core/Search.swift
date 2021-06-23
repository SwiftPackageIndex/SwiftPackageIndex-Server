import Fluent
import SQLKit
import Vapor


enum Search {
    static let schema = "search"
    
    // identifiers
    static let id = SQLIdentifier("id")
    static let keywords = SQLIdentifier("keywords")
    static let packageName = SQLIdentifier("package_name")
    static let repoName = SQLIdentifier("name")
    static let repoOwner = SQLIdentifier("owner")
    static let rowNumber = SQLIdentifier("row_number")
    static let summary = SQLIdentifier("summary")
    static let score = SQLIdentifier("score")
    static let searchView = SQLIdentifier("search")
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
        var keyword: String?
        var matchType: MatchType
        var packageId: Package.Id?
        var packageName: String?
        var repositoryName: String?
        var repositoryOwner: String?
        var summary: String?
        
        enum CodingKeys: String, CodingKey {
            case keyword
            case matchType = "match_type"
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
        let mergedTerms = SQLBind(terms.joined(separator: " ").lowercased())
        let binds = terms[..<min(terms.count, maxSearchTerms)].map(SQLBind.init)

        // constants
        let empty = SQLLiteral.string("")
        let space = SQLLiteral.string(" ")
        let contains = SQLRaw("~*")

        let haystack = concat(
            packageName, space, coalesce(summary, empty), space, repoName, space, repoOwner
        )
        let orderBy = SQLOrderBy(eq(lower(packageName), mergedTerms), .descending)
            .then(score, .descending)
            .then(packageName, .ascending)

        let preamble = db
            .select()
            .column(.package)
            .column(id)
            .column(packageName)
            .column(repoName)
            .column(repoOwner)
            .column(summary)
            .column(keywords)
            .column(SQLFunction.rowNumber.over(orderBy: orderBy), as: rowNumber)
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
            .column(null, as: id)
            .column(null, as: packageName)
            .column(null, as: repoName)
            .column(null, as: repoOwner)
            .column(null, as: summary)
            .column(null, as: keywords)
            .column(SQLFunction.rowNumber.over(), as: rowNumber)
            .from(searchView)
            .where(mergedTerms, .like, SQLFunction("ANY", args: keywords))
        // TODO: limit?
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

        // page is one-based, clamp it to 0-based offset
        let offset = ((page - 1) * pageSize).clamped(to: 0...)
        let limit = pageSize + 1  // fetch one more so we can determine `hasMoreResults`

        let union = db.unionAll(
            keywordMatchQueryBuilder(on: database, terms: sanitizedTerms),
            packageMatchQueryBuilder(on: database, terms: sanitizedTerms,
                                     offset: offset, limit: limit)
        )

        return db.select()
            .column("*")
            .from(
                SQLAlias(SQLGroupExpression(union.query), as: SQLIdentifier("t"))
            )
            .orderBy(SQLOrderBy(MatchType.equals(.keyword), .descending))
            .orderBy(SQLOrderBy(MatchType.equals(.package), .descending))
            .orderBy(rowNumber)
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


private extension SQLSelectBuilder {
    // sas 2020-06-05: workaround `direction: SQLExpression` signature in SQLKit
    // (should be SQLDirection)
    func orderBy(_ expression: SQLExpression, _ direction: SQLDirection = .ascending) -> Self {
        return self.orderBy(SQLOrderBy(expression: expression, direction: direction))
    }

    func column(_ matchType: Search.MatchType) -> Self {
        column(matchType.sqlAlias)
    }

    func column(_ expression: SQLExpression, as alias: SQLExpression) -> Self {
        column(SQLAlias(expression, as: alias))
    }
}


public struct SQLOver: SQLExpression {
    public let windowFunction: SQLFunction
    public let orderBy: SQLExpression?

    public init(_ windowFunction: SQLFunction) {
        self.windowFunction = windowFunction
        self.orderBy = nil
    }

    public init(_ windowFunction: SQLFunction, orderBy: SQLOrderBy) {
        self.windowFunction = windowFunction
        self.orderBy = orderBy
    }

    public init(_ windowFunction: SQLFunction, orderBy: SQLOrderByGroup) {
        self.windowFunction = windowFunction
        self.orderBy = orderBy
    }

    public func serialize(to serializer: inout SQLSerializer) {
        windowFunction.serialize(to: &serializer)
        serializer.write(" OVER (")
        if let expr = orderBy {
            serializer.write("ORDER BY ")
            expr.serialize(to: &serializer)
        }
        serializer.write(")")
    }
}


extension SQLFunction {
    func over() -> SQLOver {
        SQLOver(self)
    }

    func over(orderBy identifier: String, _ direction: SQLDirection = .ascending) -> SQLOver {
        over(orderBy: SQLIdentifier(identifier), direction)
    }

    func over(orderBy expression: SQLExpression, _ direction: SQLDirection = .ascending) -> SQLOver {
        over(orderBy: SQLOrderBy(expression, direction))
    }

    func over(orderBy expression: SQLOrderBy) -> SQLOver {
        SQLOver(self, orderBy: expression)
    }

    func over(orderBy expression: SQLOrderByGroup) -> SQLOver {
        SQLOver(self, orderBy: expression)
    }

    static var rowNumber: Self { .init("ROW_NUMBER") }
}


public struct SQLOrderByGroup: SQLExpression {
    public let orderByClauses: [SQLOrderBy]

    public init(_ orderby: SQLOrderBy...) {
        self.orderByClauses = orderby
    }

    public init(_ orderby: [SQLOrderBy]) {
        self.orderByClauses = orderby
    }

    public func serialize(to serializer: inout SQLSerializer) {
        guard let first = orderByClauses.first else { return }
        first.serialize(to: &serializer)
        for clause in orderByClauses.dropFirst() {
            serializer.write(", ")
            clause.serialize(to: &serializer)
        }
    }

    func then(_ expression: SQLExpression, _ direction: SQLDirection = .ascending) -> Self {
        SQLOrderByGroup(orderByClauses + [SQLOrderBy(expression, direction)])
    }

    func then(_ expression: SQLOrderBy) -> Self {
        SQLOrderByGroup(orderByClauses + [expression])
    }
}


extension SQLOrderBy {
    init(_ expression: SQLExpression, _ direction: SQLDirection) {
        self.init(expression: expression, direction: direction)
    }

    func then(_ expression: SQLExpression, _ direction: SQLDirection = .ascending) -> SQLOrderByGroup {
        SQLOrderByGroup([self, SQLOrderBy(expression, direction)])
    }

    func then(_ expression: SQLOrderBy) -> SQLOrderByGroup {
        SQLOrderByGroup([self, expression])
    }
}
