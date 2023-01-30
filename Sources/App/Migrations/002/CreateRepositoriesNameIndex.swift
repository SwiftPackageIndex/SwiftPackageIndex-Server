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

import Fluent
import SQLKit


struct CreateRepositoriesNameIndex: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }

        // See https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/176#issuecomment-637710906
        // for details about this index
        return db.raw("CREATE EXTENSION pg_trgm").run()
            .flatMap {
                db.raw("CREATE INDEX idx_repositories_name ON repositories USING gin (name gin_trgm_ops)").run() }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        return
            db.raw("DROP INDEX idx_repositories_name").run()
            .flatMap { db.raw("DROP EXTENSION pg_trgm").run() }
    }
}
