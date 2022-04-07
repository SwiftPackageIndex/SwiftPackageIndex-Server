@testable import App

import FluentKit
import SQLKit
import Vapor


actor TestSchema {
    private var _app: Application!
    private var isMigrated = false
    private var tableNamesCache: [String]?

    func client() -> Client {
        guard let app = _app else {
            fatalError("setup() must be called before accessing the database")
        }
        return app.client
    }

    func db() -> Database {
        guard let app = _app else {
            fatalError("setup() must be called before accessing the database")
        }
        return app.db
    }

    func logger() -> Logger {
        guard let app = _app else {
            fatalError("setup() must be called before accessing the database")
        }
        return app.logger
    }

    func threadPool() -> NIOThreadPool {
        guard let app = _app else {
            fatalError("setup() must be called before accessing the database")
        }
        return app.threadPool
    }

    func setup(_ environment: Environment, resetDb: Bool) async throws -> Application {
        if _app != nil {
            shutdown()
        }
        _app = Application(environment)
        let host = try configure(_app)

        // Ensure `.testing` refers to "postgres" or "localhost"
        precondition(["localhost", "postgres", "host.docker.internal"].contains(host),
                     ".testing must be a local db, was: \(host)")

        _app.logger.logLevel = Environment.get("LOG_LEVEL").flatMap(Logger.Level.init(rawValue:)) ?? .warning

        if !isMigrated {
            try await _app.autoMigrate()
            isMigrated = true
        }
        if resetDb { try await resetDB() }

        // Always start with a baseline mock environment to avoid hitting live resources
        Current = .mock(eventLoop: _app.eventLoopGroup.next())

        return _app
    }

    func shutdown() {
        guard let app = _app else {
            fatalError("setup() must be called before accessing the database")
        }
        app.shutdown()
        _app = nil
    }

    func resetDB() async throws {
        guard let app = _app else {
            fatalError("setup() must be called before accessing the database")
        }
        guard let db = app.db as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }

        guard let tables = tableNamesCache else {
            struct Row: Decodable { var table_name: String }
            tableNamesCache = try await db.raw("""
                    SELECT table_name FROM
                    information_schema.tables
                    WHERE
                      table_schema NOT IN ('pg_catalog', 'information_schema', 'public._fluent_migrations')
                      AND table_schema NOT LIKE 'pg_toast%'
                      AND table_name NOT LIKE '_fluent_%'
                    """)
                .all(decoding: Row.self)
                .map(\.table_name)
            if tableNamesCache != nil {
                try await resetDB()
            }
            return
        }

        for table in tables {
            try await db.raw("TRUNCATE TABLE \(raw: table) CASCADE").run()
        }
    }

    func updateEnvironment(_ update: (inout AppEnvironment) -> Void) async {
        update(&Current)
    }

}

