import Foundation

@testable import App

import ShellOut
import Testing


@Suite(.setupDatabasePool)
struct DatabasePoolTests {
    @Test(arguments: (0..<10))
    func dbPoolTest(_ id: Int) async throws {
        try await DatabasePool.shared.withDatabase { id in
            print("⚠️", id)
            try await Task.sleep(for: .milliseconds(500))
        }
    }
}
