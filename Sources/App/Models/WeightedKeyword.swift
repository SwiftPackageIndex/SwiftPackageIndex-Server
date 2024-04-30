// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
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

import Vapor
import Fluent
import SQLKit


struct WeightedKeyword: Codable, Equatable {
    var keyword: String
    var count: Int
}


extension WeightedKeyword {
    static let schema = "weighted_keywords"

    enum Field {
        static var count: SQLIdentifier { "count" }
        static var keyword: SQLIdentifier { "keyword" }
    }

    static func query(on database: Database, keywords: [String]) async throws -> [Self] {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }

        if keywords.isEmpty {
            return []
        }

        return try await db.select()
            .column(Field.keyword)
            .column(Field.count)
            .from(schema)
            .where(Field.keyword, .in, keywords)
            .all(decoding: Self.self)
    }

    static func refresh(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        return db.raw("REFRESH MATERIALIZED VIEW \(ident: Self.schema)").run()
    }
}


extension Array where Element == WeightedKeyword {
    func weight(for keyword: String) -> Int {
        first { $0.keyword == keyword }?.count ?? 0
    }
}
