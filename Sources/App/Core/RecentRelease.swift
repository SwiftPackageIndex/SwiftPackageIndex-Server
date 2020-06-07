import Fluent
import Foundation
import SQLKit


struct RecentRelease: Decodable, Equatable {
    static let schema = "recent_releases"

    var id: UUID
    var repositoryOwner: String
    var repositoryName: String
    var packageName: String
    var version: String
    var releasedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case repositoryOwner = "repository_owner"
        case repositoryName = "repository_name"
        case packageName = "package_name"
        case version
        case releasedAt = "released_at"
    }
}

extension RecentRelease {
    static func refresh(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        return db.raw("REFRESH MATERIALIZED VIEW \(Self.schema)").run()
    }


    static func fetch(on database: Database,
                      limit: Int = Constants.recentPackagesLimit) -> EventLoopFuture<[RecentRelease]> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        return db.raw("SELECT * FROM \(Self.schema) ORDER BY released_at DESC LIMIT \(bind: limit)")
            .all(decoding: RecentRelease.self)
    }
}
