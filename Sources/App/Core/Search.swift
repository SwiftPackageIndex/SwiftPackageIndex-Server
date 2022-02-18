// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
    static let lastActivityAt = SQLIdentifier("last_activity_at")
    static let levenshteinDist = SQLIdentifier("levenshtein_dist")
    static let license = SQLIdentifier("license")
    static let lastCommitDate = SQLIdentifier("last_commit_date")
    static let searchView = SQLIdentifier("search")
    static let summary = SQLIdentifier("summary")

    static let ilike = SQLRaw("ILIKE")
    static let null = SQLRaw("NULL")
    static let nullInt = SQLRaw("NULL::INT")
    static let nullUUID = SQLRaw("NULL::UUID")
    static let nullTimestamp = SQLRaw("NULL::TIMESTAMP")

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
        var searchTerm: String
        var searchFilters: [SearchFilter.ViewModel]
        var results: [Search.Result]
    }

    struct DBRecord: Content, Equatable {
        var matchType: MatchType
        var keyword: String?
        var packageId: Package.Id?
        var packageName: String?
        var repositoryName: String?
        var repositoryOwner: String?
        var stars: Int?
        var lastActivityAt: Date?
        var summary: String?
        
        enum CodingKeys: String, CodingKey {
            case matchType = "match_type"
            case keyword
            case packageId = "package_id"
            case packageName = "package_name"
            case repositoryName = "repo_name"
            case repositoryOwner = "repo_owner"
            case stars
            case lastActivityAt = "last_activity_at"
            case summary
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
            .map { $0.replacingOccurrences(of: "\\", with: "") }
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
                                         filters: [SearchFilterProtocol],
                                         offset: Int? = nil,
                                         limit: Int? = nil) -> SQLSelectBuilder {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }

        let maxSearchTerms = 20 // just to impose some sort of limit

        // binds
        let binds = terms[..<min(terms.count, maxSearchTerms)].map(SQLBind.init)
        let mergedTerms = SQLBind(terms.joined(separator: " ").lowercased())

        // constants
        let empty = SQLLiteral.string("")
        let contains = SQLRaw("~*")

        let haystack = concat(
            with: " ",
            packageName, coalesce(summary, empty), repoName, repoOwner, arrayToString(keywords, delimiter: " ")
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
            .column(lastActivityAt)
            .column(null, as: levenshteinDist)
            .from(searchView)
            .from(SQLFunction("CONCAT", args: keywords), as: keyword)

        return binds.reduce(preamble) { $0.where(haystack, contains, $1) }
            .where(isNotNull(repoOwner))
            .where(isNotNull(repoName))
            .where(searchFilters: filters)
            .orderBy(sortOrder)
            .offset(offset)
            .limit(limit)
    }

    static func keywordMatchQueryBuilder(on database: Database,
                                         terms: [String]) -> SQLSelectBuilder {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        let mergedTerms = terms.joined(separator: " ").lowercased()
        let searchPattern = mergedTerms.isEmpty ? "" : "%" + mergedTerms + "%"

        return db
            .select()
            .distinct()
            .column(.keyword)
            .column(keyword)
            .column(nullUUID, as: packageId)
            .column(null, as: packageName)
            .column(null, as: repoName)
            .column(null, as: repoOwner)
            .column(nullInt, as: score)
            .column(null, as: summary)
            .column(nullInt, as: stars)
            .column(null, as: license)
            .column(nullTimestamp, as: lastCommitDate)
            .column(nullTimestamp, as: lastActivityAt)
            .column(SQLFunction("LEVENSHTEIN", args: keyword, SQLBind(mergedTerms)),
                    as: levenshteinDist)
            .from(searchView)
            .from(SQLFunction("UNNEST", args: keywords), as: keyword)
            .where(keyword, ilike, SQLBind(searchPattern))
            .orderBy(levenshteinDist)
            .limit(15)
    }

    static func authorMatchQueryBuilder(on database: Database,
                                        terms: [String]) -> SQLSelectBuilder {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        let mergedTerms = terms.joined(separator: " ").lowercased()
        let searchPattern = mergedTerms.isEmpty ? "" : "%" + mergedTerms + "%"

        return db
            .select()
            .distinct()
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
            .column(nullTimestamp, as: lastActivityAt)
            .column(SQLFunction("LEVENSHTEIN", args: repoOwner, SQLBind(mergedTerms)),
                    as: levenshteinDist)
            .from(searchView)
            .where(repoOwner, ilike, SQLBind(searchPattern))
            .orderBy(levenshteinDist)
            .limit(15)
    }

    static func query(_ database: Database,
                      _ sanitizedTerms: [String],
                      filters: [SearchFilterProtocol] = [],
                      page: Int,
                      pageSize: Int) -> SQLSelectBuilder? {
        //  This function assembles results from the different search types (packages,
        //  keywords, ...) into a single query.
        //
        //  Each subquery type has its column where it "sends" the data it finds and
        //  the other columns are reported back as `NULL`. I.e.
        //  ```
        //  match_type | keyword | package_name | ... | repo_owner
        //  package      NULL      foo                  bar
        //  keyword      ios       NULL                 NULL
        //  author       NULL      NULL                 bar
        //  ```
        //  `package` being a slight exception in that it also needs the `repo_owner`
        //  field (which is the author field) to report back all of the data required
        //  for the package search result type.
        //  What we're effectively doing is trying to create an enum in SQL such that
        //  we can `UNION ALL` different cases together and map them onto an `enum`
        //  case when we decode the rows into enums on the Swift side.

        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }

        // ensure we have at least one filter or one term in order to search
        if sanitizedTerms.isEmpty && filters.isEmpty {
            return nil
        }

        // page is one-based, clamp it to ensure we get a >=0 offset
        let page = page.clamped(to: 1...)
        let offset = (page - 1) * pageSize
        let limit = pageSize + 1  // fetch one more so we can determine `hasMoreResults`

        // only include non-package results on first page
        let query = page == 1
        ? authorMatchQueryBuilder(on: database, terms: sanitizedTerms)
            .union(all: { _ in
                keywordMatchQueryBuilder(on: database, terms: sanitizedTerms)

            })
            .union(all: { _ in
                packageMatchQueryBuilder(on: database,
                                         terms: sanitizedTerms,
                                         filters: filters,
                                         offset: offset,
                                         limit: limit)

            }).query
        : packageMatchQueryBuilder(on: database,
                                   terms: sanitizedTerms,
                                   filters: filters,
                                   offset: offset,
                                   limit: limit).query

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
        let (sanitizedTerms, filters) = SearchFilter.split(terms: sanitize(terms))
        
        // Metrics
        AppMetrics.searchTermsCount?.set(sanitizedTerms.count)
        AppMetrics.searchFiltersCount?.set(filters.count)
        
        guard let query = query(database,
                                sanitizedTerms,
                                filters: filters,
                                page: page,
                                pageSize: pageSize) else {
            return database.eventLoop.future(.init(hasMoreResults: false,
                                                   searchTerm: sanitizedTerms.joined(separator: " "),
                                                   searchFilters: [],
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
                                       searchTerm: sanitizedTerms.joined(separator: " "),
                                       searchFilters: filters.map { $0.viewModel },
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
