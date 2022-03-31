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
import Foundation
import SQLKit


struct Stats: Decodable, Equatable {
    static let schema = "stats"
    
    var packageCount: Int
    var versionCount: Int
    var missingBuildPackageCount: Int
    
    enum CodingKeys: String, CodingKey {
        case packageCount = "package_count"
        case versionCount = "version_count"
        case missingBuildPackageCount = "missing_build_package_count"
    }
}

extension Stats {
    static func refresh(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        return db.raw("REFRESH MATERIALIZED VIEW \(raw: Self.schema)").run()
    }
    
    
    static func fetch(on database: Database) -> EventLoopFuture<Stats?> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        return db.raw("SELECT * FROM \(raw: Self.schema)")
            .first(decoding: Stats.self)
    }
}
