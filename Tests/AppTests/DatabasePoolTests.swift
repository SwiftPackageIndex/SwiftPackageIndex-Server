import Foundation

@testable import App

import ShellOut
import Testing


actor DatabasePool {
    typealias DatabaseID = UUID
    struct DatabaseInfo: Hashable {
        var id: DatabaseID
        var port: Int
    }

    static let maxCount = 2
    var availableDatabaseIDs: Set<DatabaseInfo> = .init()

    func withDatabase(_ operation: (DatabaseInfo) async throws -> Void) async throws {
        let dbID = try await retainDatabase()

        do {
            print("⚠️ available", availableDatabaseIDs.map(\.port).sorted())
            try await operation(dbID)
            try await releaseDatabase(dbInfo: dbID)
        } catch {
            try await releaseDatabase(dbInfo: dbID)
            throw error
        }
    }

    private func retainDatabase() async throws -> DatabaseInfo {
        var dbInfo = availableDatabaseIDs.randomElement()
        while dbInfo == nil {
            if availableDatabaseIDs.count < Self.maxCount {
                dbInfo = try await Self.launchDB()
            } else {
                try await Task.sleep(for: .milliseconds(100))
                dbInfo = availableDatabaseIDs.randomElement()
            }
        }
        guard let dbInfo else { fatalError("dbInfo cannot be nil here") }
        availableDatabaseIDs.remove(dbInfo)
        return dbInfo
    }

    private func releaseDatabase(dbInfo: DatabaseInfo) async throws {
        availableDatabaseIDs.insert(dbInfo)
    }

    private static func launchDB(maxAttempts: Int = 3) async throws -> DatabaseInfo {
        let id = UUID()
        let port = Int.random(in: 10_000...65_000)
        _ = try? await ShellOut.shellOut(to: .removeDB(id: id))
        var attemptsLeft = maxAttempts
        while attemptsLeft > 0 {
            do {
                print("⚠️ Launching DB \(id) on port \(port)")
                try await ShellOut.shellOut(to: .launchDB(id: id, port: port))
            } catch {
                if attemptsLeft != maxAttempts {
                    try? await Task.sleep(for: .milliseconds(200))
                }
                attemptsLeft -= 1
            }
        }
        return .init(id: id, port: port)
    }

    private static func removeDB(dbInfo: DatabaseInfo, maxAttempts: Int = 3) async throws {
        var attemptsLeft = maxAttempts
        while attemptsLeft > 0 {
            do {
                print("⚠️ Removing DB \(dbInfo.id) on port \(dbInfo.port)")
                try await ShellOut.shellOut(to: .removeDB(id: dbInfo.id))
            } catch {
                if attemptsLeft != maxAttempts {
                    try? await Task.sleep(for: .milliseconds(200))
                }
                attemptsLeft -= 1
            }
        }
    }
}


private let dbPool = DatabasePool()


@Suite struct DatabasePoolTests {
    @Test(arguments: (0..<5))
    func dbPoolTest(_ id: Int) async throws {
        try await dbPool.withDatabase { id in
            print("⚠️", id)
            try await Task.sleep(for: .milliseconds(500))
        }
    }

}
