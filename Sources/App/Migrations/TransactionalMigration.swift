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


/// Runs a migration's `prepare`/`revert` inside a transaction, so a migration that fails part way
/// through leaves no partial schema change behind.
///
/// This narrows the window rather than closing it. FluentKit's migrator commits `prepare` and then
/// inserts the `migrations` row as a second, separate operation (`Migrator.prepare`), and that
/// insert stays outside the transaction opened here - a wrapper expressed as a `Migration` cannot
/// reach it. So a multi-step migration that throws no longer commits its earlier steps, but a
/// migration that succeeds and then loses the connection before the row lands still re-runs against
/// an already-changed schema. Closing that needs a replacement for the `migrate` command.
///
/// Migrations that open a transaction of their own (036, 037, 044) can be wrapped safely: Postgres
/// has no nested transactions and FluentKit makes the inner `transaction` call a passthrough when
/// one is already open.
struct TransactionalMigration: AsyncMigration {
    private let wrapped: any AsyncMigration

    init(_ migration: any AsyncMigration) {
        self.wrapped = migration
    }

    var name: String { wrapped.name }

    func prepare(on database: Database) async throws {
        try await database.transaction { try await wrapped.prepare(on: $0) }
    }

    func revert(on database: Database) async throws {
        try await database.transaction { try await wrapped.revert(on: $0) }
    }
}
