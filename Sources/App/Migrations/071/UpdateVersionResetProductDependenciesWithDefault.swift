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


struct UpdateVersionResetProductDependenciesWithDefault: AsyncMigration {
    func prepare(on database: Database) async throws {
        // re-create field without default
        try await database.schema("versions")
            .deleteField("product_dependencies")
            .update()
        try await database.schema("versions")
            .field("product_dependencies",
                   .array(of: .json))
            .update()
    }

    func revert(on database: Database) async throws {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }

        // set default on product_dependencies
        // we can't revert the field reset so we just leave the values as they are
        try await db.raw(#"ALTER TABLE versions ALTER COLUMN product_dependencies SET DEFAULT '{}'"#).run()
    }
}
