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

struct UpdateVersionCommitDateNotNullable: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.transaction { tx in
            guard let db = tx as? SQLDatabase else {
                fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
            }
            try await db.raw(
                #"DELETE FROM "versions" WHERE "commit_date" IS NULL"#
            ).run()
            try await db.raw(
                #"ALTER TABLE "versions" ALTER COLUMN "commit_date" SET NOT NULL"#
            ).run()
        }
    }

    func revert(on database: Database) async throws {
        try await database.transaction { tx in
            guard let db = tx as? SQLDatabase else {
                fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
            }
            try await db.raw(
                #"ALTER TABLE "versions" ALTER COLUMN "commit_date" DROP NOT NULL"#
            ).run()
        }

    }
}
