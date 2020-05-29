import Fluent
import SQLKit
import Vapor


struct SearchResult: Content, Equatable {
    let hasMoreResults: Bool
    let results: [Search.Record]
}

enum Search {
    static let schema = "search"

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
            case summary
        }
    }

    static var preamble: String {
        """
        select
        id,
        package_name,
        name,
        owner,
        summary
        from search
        """
    }

    static func regexClause(_ term: String) -> String {
        "coalesce(package_name) || ' ' || coalesce(summary, '') || ' ' || coalesce(name, '') || ' ' || coalesce(owner, '') ~* '\(term)'"
    }

    static func build(_ terms: [String]) -> String {
        preamble
            + "\nwhere "
            + terms.map(regexClause).joined(separator: "\nand ")
            + "\n  order by score desc"
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

    static func refresh(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        return db.raw("REFRESH MATERIALIZED VIEW \(Self.schema)").run()
    }
}
