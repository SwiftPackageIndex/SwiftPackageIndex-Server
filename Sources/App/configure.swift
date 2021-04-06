import Fluent
import FluentPostgresDriver
import Vapor


public func configure(_ app: Application) throws {
    app.logger.component = "server"
    Current.setLogger(app.logger)

    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
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

    let tlsConfig: TLSConfiguration? = Environment.get("DATABASE_USE_TLS")
        .flatMap(\.asBool)
        .flatMap { $0 ? .clientDefault : nil }
    app.databases.use(.postgres(hostname: host,
                                port: port,
                                username: username,
                                password: password,
                                database: database,
                                tlsConfiguration: tlsConfig), as: .psql)
    
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
    do {  // Migration 015 - add unique index to builds
        app.migrations.add(UpdateBuildUniqueIndex1())
    }
    do {  // Migration 016 - add job_url field to builds
        app.migrations.add(UpdateBuildAddJobUrl())
    }
    do {  // Migration 017 - remove logs field from builds
        app.migrations.add(UpdateBuildRemoveLogs())
    }
    do {  // Migration 018 - add license_url to repositories
        app.migrations.add(UpdateRepositoryAddLicenseUrl())
    }
    do {  // Migration 019 - add readme_url to repositories
        app.migrations.add(UpdateRepositoryAddReadmeUrl())
    }
    do {  // Migration 020 - add tools_version to versions
        app.migrations.add(UpdateVersionAddToolsVersion())
    }
    do {  // Migration 021 - add release_url to recent_releases and url to versions
        app.migrations.add(UpdateVersionAddUrl())
        app.migrations.add(UpdateRecentReleases5())
    }
    do {  // Migration 022 - add is_archived to repositories
        app.migrations.add(UpdateRepositoryAddIsArchived())
    }
    do {  // Migration 023 - add releases to repositories and published_at and release_notes to versions
        app.migrations.add(UpdateRepositoryAddReleases())
        app.migrations.add(UpdateVersionAddPublisedAtReleaseNotes())
    }
    do {  // Migration 024 - add targets table
        app.migrations.add(CreateTarget())
    }
    do {  // Migration 025 - add targets to products
        app.migrations.add(UpdateProductAddTargets())
    }
    do {  // Migration 026 - Add rendered README url
        app.migrations.add(UpdateRepositoriesAddReadmeHtmlUrl())
    }

    app.commands.use(AnalyzeCommand(), as: "analyze")
    app.commands.use(CreateRestfileCommand(), as: "create-restfile")
    app.commands.use(DeleteBuildsCommand(), as: "delete-builds")
    app.commands.use(IngestCommand(), as: "ingest")
    app.commands.use(ReconcileCommand(), as: "reconcile")
    app.commands.use(TriggerBuildsCommand(), as: "trigger-builds")
    app.commands.use(ReAnalyzeVersionsCommand(), as: "re-analyze-versions")
    
    // register routes
    try routes(app)

    // bootstrap app metrics
    AppMetrics.bootstrap()
}
