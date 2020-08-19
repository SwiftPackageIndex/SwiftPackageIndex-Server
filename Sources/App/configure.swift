import Fluent
import FluentPostgresDriver
import Vapor


public func configure(_ app: Application) throws {
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory + "deploy/"))
    app.middleware.use(ErrorMiddleware())
    
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
    
    do {  // Migration 001 - schema 1.0
        app.migrations.add(CreatePackage())
        app.migrations.add(CreateRepository())
        app.migrations.add(CreateVersion())
        app.migrations.add(CreateProduct())
        app.migrations.add(CreateRecentPackages())
        app.migrations.add(CreateRecentReleases())
        app.migrations.add(CreateSearch())
    }
    do {  // Migration 002 - unique owner/repository index
        app.migrations.add(CreateOwnerRepositoryIndex())
        app.migrations.add(CreateRepositoriesNameIndex())
    }
    do {  // Migration 003 - update recent packages/releases views
        app.migrations.add(UpdateRecentPackages1())
        app.migrations.add(UpdateRecentReleases1())
    }
    do {  // Migration 004 - make status required, defaulting to 'new'
        app.migrations.add(UpdatePackageStatusNew())
    }
    do {  // Migration 005 - update recent packages/releases views
        app.migrations.add(UpdateRecentPackages2())
        app.migrations.add(UpdateRecentReleases2())
    }
    do {  // Migration 006 - update recent releases view
        app.migrations.add(UpdateRecentReleases3())
    }
    do {  // Migration 007 - dedupe package name changes
        app.migrations.add(UpdateRecentPackages3())
        app.migrations.add(UpdateRecentReleases4())
    }
    do {  // Migration 008 - add stats view
        app.migrations.add(CreateStats())
    }
    do {  // Migration 009 - add builds table
        app.migrations.add(CreateBuild())
    }
    do {  // Migration 010 - add non-null constraints to builds fields
        app.migrations.add(UpdateBuildNonNull())
    }
    do {  // Migration 011 - add log_url field to builds
        app.migrations.add(UpdateBuildAddLogURL())
    }
    do {  // Migration 012 - change platfrom to .string
        app.migrations.add(UpdateBuildPlatform())
    }
    do {  // Migration 013 - add build command
        app.migrations.add(UpdateBuildAddBuildCommand())
    }
    do {  // Migration 014 - add latest
        app.migrations.add(UpdateVersionAddLatest())
    }
    do {  // Migration 015 -
        app.migrations.add(UpdateBuildUniqueIndex1())
    }
    
    app.commands.use(AnalyzeCommand(), as: "analyze")
    app.commands.use(CreateRestfileCommand(), as: "create-restfile")
    app.commands.use(IngestCommand(), as: "ingest")
    app.commands.use(ReconcileCommand(), as: "reconcile")
    app.commands.use(TriggerBuildsCommand(), as: "trigger-builds")
    
    // register routes
    try routes(app)
}
