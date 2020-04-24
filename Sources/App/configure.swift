import Fluent
import FluentPostgresDriver
import Vapor

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.databases.use(.postgres(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        username: Environment.get("DATABASE_USERNAME") ?? "spmidx_dev",
        password: Environment.get("DATABASE_PASSWORD") ?? "xxx",
        database: Environment.get("DATABASE_NAME") ?? "spmidx_dev"
    ), as: .psql)

    app.migrations.add(CreateTodo())

    // register routes
    try routes(app)
}