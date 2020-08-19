import Fluent
import Foundation
import SQLKit


struct RecentPackage: Decodable, Equatable {
    static let schema = "recent_packages"
    
    var id: UUID
    var repositoryOwner: String
    var repositoryName: String
    var packageName: String
    var packageSummary: String?
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case repositoryOwner = "repository_owner"
        case repositoryName = "repository_name"
        case packageName = "package_name"
        case packageSummary = "package_summary"
        case createdAt = "created_at"
    }
}

extension RecentPackage {
    static func refresh(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        return db.raw("REFRESH MATERIALIZED VIEW \(raw: Self.schema)").run()
    }
    
    
    static func fetch(on database: Database,
                      limit: Int = Constants.recentPackagesLimit) -> EventLoopFuture<[RecentPackage]> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        return db.raw("SELECT * FROM \(raw: Self.schema) ORDER BY created_at DESC LIMIT \(bind: limit)")
            .all(decoding: RecentPackage.self)
    }
}
