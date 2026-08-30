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

@testable import App

import Fluent
import SQLKit
import Testing


extension AllTests.TransactionalMigrationTests {

    // A migration that performs a schema change and then fails, i.e. the shape of every
    // multi-step migration in `Migrations/` when its second step throws.
    private struct FailingTwoStep: AsyncMigration {
        struct Failure: Error, Equatable { }

        var table: String

        func prepare(on database: Database) async throws {
            try await database.schema(table).id().create()
            throw Failure()
        }

        func revert(on database: Database) async throws {
            try await database.schema(table).delete()
            throw Failure()
        }
    }

    @Test func name_isForwardedToWrappedMigration() throws {
        // The `migrations` table keys off `Migration.name`. If wrapping changed it, every
        // migration would look unapplied and re-run against production databases.
        #expect(TransactionalMigration(CreatePackage()).name == "App.CreatePackage")
    }

    @Test func prepare_rollsBackPartialWork() async throws {
        try await withSPIApp { app in
            let migration = FailingTwoStep(table: "t_prepare_rollback")

            await #expect(throws: FailingTwoStep.Failure.self) {
                try await TransactionalMigration(migration).prepare(on: app.db)
            }

            let exists = try await tableExists(migration.table, on: app.db)
            #expect(exists == false)
        }
    }

    @Test func revert_rollsBackPartialWork() async throws {
        try await withSPIApp { app in
            let migration = FailingTwoStep(table: "t_revert_rollback")
            try await app.db.schema(migration.table).id().create()

            await #expect(throws: FailingTwoStep.Failure.self) {
                try await TransactionalMigration(migration).revert(on: app.db)
            }

            let exists = try await tableExists(migration.table, on: app.db)
            #expect(exists == true)
        }
    }

    @Test func prepare_withoutWrapping_leavesPartialWork() async throws {
        // Characterises the behaviour being fixed: FluentKit's migrator does not open a
        // transaction of its own, so an unwrapped migration commits its completed steps.
        try await withSPIApp { app in
            let migration = FailingTwoStep(table: "t_unwrapped")

            await #expect(throws: FailingTwoStep.Failure.self) {
                try await migration.prepare(on: app.db)
            }

            let exists = try await tableExists(migration.table, on: app.db)
            #expect(exists == true)
        }
    }

    @Test func prepare_toleratesNestedTransaction() async throws {
        // Migrations 036/037/044 open a transaction of their own. Postgres has no nested
        // transactions; FluentKit makes the inner call a passthrough. Verify wrapping those
        // still commits.
        struct SelfTransacting: AsyncMigration {
            var table: String

            func prepare(on database: Database) async throws {
                try await database.transaction { tx in
                    try await tx.schema(table).id().create()
                }
            }

            func revert(on database: Database) async throws {
                try await database.schema(table).delete()
            }
        }

        try await withSPIApp { app in
            let migration = SelfTransacting(table: "t_nested")

            try await TransactionalMigration(migration).prepare(on: app.db)

            let exists = try await tableExists(migration.table, on: app.db)
            #expect(exists == true)
        }
    }

}


private func tableExists(_ table: String, on database: Database) async throws -> Bool {
    let db = try #require(database as? SQLDatabase)
    struct Row: Decodable { var exists: Bool }
    let rows = try await db.raw("SELECT to_regclass(\(bind: "public.\(table)")) IS NOT NULL AS exists")
        .all(decoding: Row.self)
    return rows.first?.exists ?? false
}
