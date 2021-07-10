import Fluent
import SQLKit
import Vapor


enum Search {
    static let schema = "search"
    
    // identifiers
    static let author = SQLIdentifier("author")
    static let keyword = SQLIdentifier("keyword")
    static let keywords = SQLIdentifier("keywords")
    static let packageId = SQLIdentifier("package_id")
    static let packageName = SQLIdentifier("package_name")
    static let repoName = SQLIdentifier("repo_name")
    static let repoOwner = SQLIdentifier("repo_owner")
    static let score = SQLIdentifier("score")
    static let stars = SQLIdentifier("stars")
    static let license = SQLIdentifier("license")
    static let lastCommitDate = SQLIdentifier("last_commit_date")
    static let supportedPlatforms = SQLIdentifier("supported_platforms")
    static let swiftVersions = SQLIdentifier("swift_versions")
    static let searchView = SQLIdentifier("search")
    static let summary = SQLIdentifier("summary")

    static let ilike = SQLRaw("ILIKE")
    static let null = SQLRaw("NULL")
    static let nullInt = SQLRaw("NULL::INT")
    static let nullUUID = SQLRaw("NULL::UUID")
    static let nullTimestamp = SQLRaw("NULL::TIMESTAMP")
    static let nullJSONBArray = SQLRaw("NULL::JSONB[]")

    enum MatchType: String, Codable, Equatable {
        case author
        case keyword
        case package

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
        #warning("This is temporary, we don't actually want to pull this data out into the record")
        var stars: Int?
        var license: String?
        var lastCommitDate: String?
        var supportedPlatforms: [Platform]?
        var swiftVersions: [SwiftVersion]?
        
        enum CodingKeys: String, CodingKey {
            case matchType = "match_type"
            case keyword
            case packageId = "package_id"
            case packageName = "package_name"
            case repositoryName = "repo_name"
            case repositoryOwner = "repo_owner"
            case summary
            case stars
            case license
            case lastCommitDate = "last_commit_date"
            case supportedPlatforms = "supported_platforms"
            case swiftVersions = "swift_versions"
        }
        
        var packageURL: String? {
            guard
                let owner = repositoryOwner,
                let name = repositoryName
            else { return nil }
            return SiteURL.package(.value(owner), .value(name), .none).relativeURL()
        }

        var isPackage: Bool {
            switch matchType {
                case .author, .keyword:
                    return false
                case .package:
                    return true
            }
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
    
    struct SearchFilter {
        enum Value {
            case number(Int)
            case string(String)
        }
        let field: SQLIdentifier
        let comparisonMethod: SQLBinaryOperator
        let value: Value
        
        /*
         Most of these fields do not currently exist within the `search` materalised view but this seems easy to change.
         
         Ideas:
         stars:>5 stars:<5
         keywords:>5 keywords:<5
         
         license:compatible
         swift:5
         platform:linux
         */
        
        init?(term: String) {
            let components = term
                .components(separatedBy: ":")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            guard components.count == 2 else {
                return nil
            }
            
            // Operator
            let comparisonOperator = String(components[1].prefix(1))
            switch comparisonOperator {
            case ">": comparisonMethod = .greaterThan
            case "<": comparisonMethod = .lessThan
            case "!": comparisonMethod = .notEqual
            default: comparisonMethod = .equal
            }
            
            let stringValue = comparisonMethod == .equal ? components[1] : String(components[1].dropFirst())
            guard !stringValue.isEmpty else { return nil }
            
            // Field & Value
            switch components[0] {
            case "score":
                field = score
                
                guard let numberValue = Int(stringValue) else { return nil }
                value = .number(numberValue)
            case "stars":
                field = stars
                
                guard let numberValue = Int(stringValue) else { return nil }
                value = .number(numberValue)
            case "license" where stringValue == "compatible":
                field = license
                value = .string(stringValue)
            default: return nil
            }
        }
    }
    
    static func extractFiltersFromTerms(terms: [String]) -> (terms: [String], filters: [SearchFilter]) {
        return terms.reduce(into: (terms: [], filters: [])) { builder, term in
            if let filter = SearchFilter(term: term) {
                builder.filters.append(filter)
            } else {
                builder.terms.append(term)
            }
        }
    }

    static func packageMatchQueryBuilder(on database: Database,
                                         terms: [String],
                                         offset: Int? = nil,
                                         limit: Int? = nil) -> SQLSelectBuilder {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }

        let (terms, filters) = extractFiltersFromTerms(terms: terms)
        let maxSearchTerms = 20 // just to impose some sort of limit

        // binds
        let binds = terms[..<min(terms.count, maxSearchTerms)].map(SQLBind.init)
        let mergedTerms = SQLBind(terms.joined(separator: " ").lowercased())

        // constants
        let empty = SQLLiteral.string("")
        let contains = SQLRaw("~*")

        let haystack = concat(
            with: " ",
            packageName, coalesce(summary, empty), repoName, repoOwner
        )
        let sortOrder = SQLOrderBy(eq(lower(packageName), mergedTerms),
                                   .descending)
            .then(score, .descending)
            .then(packageName, .ascending)

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
            .column(stars)
            .column(license)
            .column(lastCommitDate)
            .column(supportedPlatforms)
            .column(swiftVersions)
            .from(searchView)

        return binds.reduce(preamble) { $0.where(haystack, contains, $1) }
            .where(isNotNull(packageName))
            .where(isNotNull(repoOwner))
            .where(isNotNull(repoName))
            .where(group: matchesPackageFilters(filters: filters))
            .orderBy(sortOrder)
            .offset(offset)
            .limit(limit)
    }
    
    static func matchesPackageFilters(filters: [SearchFilter]) -> (SQLPredicateGroupBuilder) -> SQLPredicateGroupBuilder {
        { builder in
            filters
                .prefix(20) // just to impose some form of limit
                .reduce(builder) { builder, filter in
                    if filter.field.string == license.string {
                        builder.where(license, .in, License.allCases.filter { $0.licenseKind == .compatibleWithAppStore }.map(\.rawValue))
                    } else {
                        switch filter.value {
                        case .number(let number):
                            builder.where(filter.field, filter.comparisonMethod, number)
                        case .string(let string):
                            builder.where(filter.field, filter.comparisonMethod, string)
                        }
                    }
                    
                    return builder
                }
        }
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
            .column(null, as: stars)
            .column(null, as: license)
            .column(null, as: lastCommitDate)
            .column(null, as: supportedPlatforms)
            .column(null, as: swiftVersions)
            .from(searchView)
            .from(SQLFunction("UNNEST", args: keywords), as: keyword)
            .where(keyword, .equal, mergedTerms)
            .limit(1)
        // TODO: increase limit when we do % matching
    }

    static func authorMatchQueryBuilder(on database: Database,
                                        terms: [String]) -> SQLSelectBuilder {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        let mergedTerms = SQLBind(terms.joined(separator: " ").lowercased())
        // FIXME: bookend with `%`

        return db
            .select()
            .column(.author)
            .column(null, as: keyword)
            .column(nullUUID, as: packageId)
            .column(null, as: packageName)
            .column(null, as: repoName)
            .column(repoOwner)
            .column(nullInt, as: score)
            .column(null, as: summary)
            .column(nullInt, as: stars)
            .column(null, as: license)
            .column(nullTimestamp, as: lastCommitDate)
            .column(nullJSONBArray, as: supportedPlatforms)
            .column(nullJSONBArray, as: swiftVersions)
            .from(searchView)
            .where(repoOwner, ilike, mergedTerms)
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

        // page is one-based, clamp it to ensure we get a >=0 offset
        let page = page.clamped(to: 1...)
        let offset = (page - 1) * pageSize
        let limit = pageSize + 1  // fetch one more so we can determine `hasMoreResults`

        // only include non-package results on first page
        let query = (page == 1)
        ? db.unionAll(
            authorMatchQueryBuilder(on: database, terms: sanitizedTerms),
            keywordMatchQueryBuilder(on: database, terms: sanitizedTerms),
            packageMatchQueryBuilder(on: database, terms: sanitizedTerms,
                                     offset: offset, limit: limit)
        ).query
        : packageMatchQueryBuilder(on: database, terms: sanitizedTerms,
                                   offset: offset, limit: limit).query

        return db.select()
            .column("*")
            .from(
                SQLAlias(SQLGroupExpression(query), as: SQLIdentifier("t"))
            )
    }

    static func fetch(_ database: Database,
                      _ terms: [String],
                      page: Int,
                      pageSize: Int) -> EventLoopFuture<Search.Response> {
        let page = page.clamped(to: 1...)
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
                let hasMoreResults = results.filter(\.isPackage).count > pageSize
                // first page has non-package results prepended, extend prefix for them
                let keep = (page == 1)
                ? pageSize + results.filter{ !$0.isPackage }.count
                : pageSize
                return Search.Response(hasMoreResults: hasMoreResults,
                                       results: Array(results.prefix(keep)))
            }
    }
    
    static func refresh(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        return db.raw("REFRESH MATERIALIZED VIEW \(raw: Self.schema)").run()
    }
}
