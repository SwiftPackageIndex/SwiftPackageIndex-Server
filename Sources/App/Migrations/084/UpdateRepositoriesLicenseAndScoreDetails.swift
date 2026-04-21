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


struct UpdateRepositoriesLicenseAndScoreDetails: AsyncMigration {
    func prepare(on database: Database) async throws {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }

        // Rename "other" -> "unknown" in repositories.license
        try await db.raw("""
            UPDATE repositories
            SET license = 'unknown'
            WHERE license = 'other'
            """).run()

        // Rename "compatible" -> "known" and "incompatible" -> "known" in the score_details JSON
        try await db.raw("""
            UPDATE packages
            SET score_details = jsonb_set(score_details::jsonb, '{licenseKind}', '"known"')
            WHERE score_details::jsonb->>'licenseKind' IN ('compatible', 'incompatible')
            """).run()

        // Rename "other" -> "unknown" in the score_details JSON
        try await db.raw("""
            UPDATE packages
            SET score_details = jsonb_set(score_details::jsonb, '{licenseKind}', '"unknown"')
            WHERE score_details::jsonb->>'licenseKind' = 'other'
            """).run()
    }

    func revert(on database: Database) async throws {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }

        // Revert "unknown" -> "other" in repositories.license
        try await db.raw("""
            UPDATE repositories
            SET license = 'other'
            WHERE license = 'unknown'
            """).run()

        // This change is impossible to revert cleanly as we can't easily distinguish
        // previously-incompatible from previously-compatible. This reverts everything
        // to "known", which will then be corrected during future score recalculations.
        try await db.raw("""
            UPDATE packages
            SET score_details = jsonb_set(score_details::jsonb, '{licenseKind}', '"compatible"')
            WHERE score_details::jsonb->>'licenseKind' = 'known'
            """).run()

        // Revert "unknown" -> "other"
        try await db.raw("""
            UPDATE packages
            SET score_details = jsonb_set(score_details::jsonb, '{licenseKind}', '"other"')
            WHERE score_details::jsonb->>'licenseKind' = 'unknown'
            """).run()
    }
}
