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

    var maxCount: Int

    init(maxCount: Int) {
        self.maxCount = maxCount
    }

    var availableDatabaseIDs: Set<DatabaseInfo> = .init()

    func setUp() async throws {
        for _ in (0..<maxCount) {
            availableDatabaseIDs.insert(try await launchDB())
        }
    }

    func tearDown() async throws {
        for dbInfo in availableDatabaseIDs {
            try await removeDB(dbInfo: dbInfo)
        }
    }

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
            try await Task.sleep(for: .milliseconds(100))
            dbInfo = availableDatabaseIDs.randomElement()
        }
        guard let dbInfo else { fatalError("dbInfo cannot be nil here") }
        availableDatabaseIDs.remove(dbInfo)
        return dbInfo
    }

    private func releaseDatabase(dbInfo: DatabaseInfo) async throws {
        availableDatabaseIDs.insert(dbInfo)
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


private enum RetryError: Error {
    case maxAttemptsExceeded
}

@discardableResult
private func run<T>(maxAttempts: Int = 3, operation: (_ attempt: Int) async throws -> T) async throws -> T {
    var attemptsLeft = maxAttempts
    while attemptsLeft > 0 {
        do {
            let attempt = maxAttempts - attemptsLeft + 1
            return try await operation(attempt)
        } catch {
            print("⚠️ \(error)")
            if attemptsLeft != maxAttempts {
                try? await Task.sleep(for: .milliseconds(200))
            }
            attemptsLeft -= 1
        }
    }
    throw RetryError.maxAttemptsExceeded
}


private let databasePool = DatabasePool(maxCount: 4)


@Suite(.setupDatabasePool)
struct DatabasePoolTests {
    @Test(arguments: (0..<10))
    func dbPoolTest(_ id: Int) async throws {
        try await databasePool.withDatabase { id in
            print("⚠️", id)
            try await Task.sleep(for: .milliseconds(500))
        }
    }
}

struct DatabaseSetupTrait: SuiteTrait, TestScoping {
    func provideScope(for test: Test, testCase: Test.Case?, performing function: @Sendable () async throws -> Void) async throws {
        print("⚠️ setup")
        try await databasePool.setUp()
        try await function()
        print("⚠️ tear down")
        try await databasePool.tearDown()
    }
}

extension SuiteTrait where Self == DatabaseSetupTrait {
    static var setupDatabasePool: Self {
        Self()
    }
}
