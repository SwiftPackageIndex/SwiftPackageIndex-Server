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

import Foundation

import App
import ShellOut


actor DatabasePool {
    typealias DatabaseID = UUID

    struct DatabaseInfo: Hashable {
        var id: DatabaseID
        var port: Int
    }

    static let shared = DatabasePool(maxCount: 4)

    var maxCount: Int

    init(maxCount: Int) {
        self.maxCount = maxCount
    }

    var availableDatabases: Set<DatabaseInfo> = .init()

    func setUp() async throws {
        try await withThrowingTaskGroup(of: DatabaseInfo.self) { group in
            for _ in (0..<maxCount) {
                group.addTask {
                    try await self.launchDB()
                }
            }
            for try await info in group {
                availableDatabases.insert(info)
            }
        }
    }

    func tearDown() async throws {
        try await withThrowingTaskGroup { group in
            for dbInfo in availableDatabases {
                group.addTask {
                    try await self.removeDB(dbInfo: dbInfo)
                }
            }
            try await group.waitForAll()
        }
    }

    func withDatabase(_ operation: @Sendable (DatabaseInfo) async throws -> Void) async throws {
        let dbID = try await retainDatabase()
        do {
            print("⚠️ available", availableDatabases.map(\.port).sorted())
            try await operation(dbID)
            try await releaseDatabase(dbInfo: dbID)
        } catch {
            try await releaseDatabase(dbInfo: dbID)
            throw error
        }
    }

    private func retainDatabase() async throws -> DatabaseInfo {
        var dbInfo = availableDatabases.randomElement()
        while dbInfo == nil {
            try await Task.sleep(for: .milliseconds(100))
            dbInfo = availableDatabases.randomElement()
        }
        guard let dbInfo else { fatalError("dbInfo cannot be nil here") }
        availableDatabases.remove(dbInfo)
        return dbInfo
    }

    private func releaseDatabase(dbInfo: DatabaseInfo) async throws {
        availableDatabases.insert(dbInfo)
    }

    private func launchDB(maxAttempts: Int = 3) async throws -> DatabaseInfo {
        let id = UUID()
        let port = Int.random(in: 10_000...65_000)
        _ = try? await ShellOut.shellOut(to: .removeDB(id: id))
        try await run(maxAttempts: 3) { attempt in
            print("⚠️ Launching DB \(id) on port \(port) (attempt: \(attempt))")
            try await ShellOut.shellOut(to: .launchDB(id: id, port: port))
        }
        return .init(id: id, port: port)
    }

    private func removeDB(dbInfo: DatabaseInfo, maxAttempts: Int = 3) async throws {
        try await run(maxAttempts: 3) { attempt in
            print("⚠️ Removing DB \(dbInfo.id) on port \(dbInfo.port) (attempt: \(attempt))")
            try await ShellOut.shellOut(to: .removeDB(id: dbInfo.id))
        }
    }
}
