import Testing


actor DatabasePool {
    typealias DatabaseID = Int
    var availableDatabaseIDs: Set<DatabaseID>

    init() {
        self.availableDatabaseIDs = Set(0..<8)
    }

    func withDatabase(_ operation: (DatabaseID) async throws -> Void) async throws {
        let dbID = try await retainDatabase()

        do {
            print("⚠️ available", availableDatabaseIDs.sorted())
            try await operation(dbID)
            try await releaseDatabase(id: dbID)
        } catch {
            try await releaseDatabase(id: dbID)
            throw error
        }
    }

    private func retainDatabase() async throws -> DatabaseID {
        var dbID = availableDatabaseIDs.randomElement()
        while dbID == nil {
            try await Task.sleep(for: .milliseconds(100))
            dbID = availableDatabaseIDs.randomElement()
        }
        guard let dbID else { fatalError("dbID cannot be nil here") }
        availableDatabaseIDs.remove(dbID)
        return dbID
    }

    private func releaseDatabase(id: DatabaseID) async throws {
        availableDatabaseIDs.insert(id)
    }
}


private let dbPool = DatabasePool()


@Suite struct DatabasePoolTests {
    @Test(arguments: (0..<20))
    func dbPoolTest(_ id: DatabasePool.DatabaseID) async throws {
        try await dbPool.withDatabase { id in
            print("⚠️", id)
            try await Task.sleep(for: .milliseconds(500))
        }
    }


}
