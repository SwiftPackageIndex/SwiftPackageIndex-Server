import Fluent
import Foundation
import SQLKit


struct RecentPackage: Decodable, Equatable {
    static let schema = "recent_packages"

    var id: UUID
    var packageName: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case packageName = "package_name"
        case createdAt = "created_at"
    }
}

extension RecentPackage {
    static func refresh(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        return db.raw("REFRESH MATERIALIZED VIEW \(Self.schema)").run()
    }


    static func fetch(on database: Database) -> EventLoopFuture<[RecentPackage]> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        return db.raw("SELECT * FROM \(Self.schema) ORDER BY created_at DESC")
            .all(decoding: RecentPackage.self)
    }
}
