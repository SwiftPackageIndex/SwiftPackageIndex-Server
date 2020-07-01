import Fluent
import Foundation
import SQLKit


struct Stats: Decodable, Equatable {
    static let schema = "stats"
    
    var packageCount: Int
    var versionCount: Int
    
    enum CodingKeys: String, CodingKey {
        case packageCount = "package_count"
        case versionCount = "version_count"
    }
}

extension Stats {
    static func refresh(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        return db.raw("REFRESH MATERIALIZED VIEW \(Self.schema)").run()
    }
    
    
    static func fetch(on database: Database) -> EventLoopFuture<Stats?> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        return db.raw("SELECT * FROM \(Self.schema)")
            .first(decoding: Stats.self)
    }
}
