import Fluent
import FluentPostgresDriver
import Vapor

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    guard
        let host = Environment.get("DATABASE_HOST"),
        let port = Environment.get("DATABASE_PORT").flatMap(Int.init),
        let username = Environment.get("DATABASE_USERNAME"),
        let password = Environment.get("DATABASE_PASSWORD"),
        let database = Environment.get("DATABASE_NAME")
        else {
            let vars = ["DATABASE_HOST", "DATABASE_PORT", "DATABASE_USERNAME", "DATABASE_PASSWORD", "DATABASE_NAME"]
                .map { "\($0) = \(Environment.get($0) ?? "unset")" }
                .joined(separator: "\n")
            app.logger.error("Incomplete DB configuration:\n\(vars)")
            throw Abort(.internalServerError)
    }

    app.databases.use(.postgres(hostname: host,
                                port: port,
                                username: username,
                                password: password,
                                database: database), as: .psql)

    app.migrations.add(CreatePackage())
    app.migrations.add(CreateRepository())

    app.commands.use(IngestorCommand(), as: "ingest")
    app.commands.use(ReconcilerCommand(), as: "reconcile")

    // register routes
    try routes(app)
}
