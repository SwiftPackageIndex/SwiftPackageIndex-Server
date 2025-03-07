import Foundation

@testable import App

import ShellOut
import Testing




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
