// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Dependencies
import Fluent
import FluentPostgresDriver
import Vapor


public func configure(_ app: Application, databaseHost: String? = nil, databasePort: Int? = nil) async throws {
    app.logger.component = "server"

    // It will be tempting to uncomment/re-add these lines in the future. We should not enable
    // server-side compression as long as we pass requests through Cloudflare, which compresses
    // *all* response data before it hits client browsers. If we compress first, then Cloudflare
    // must decompress our response before recompressing using a different algorithm.
    // ---
    // app.http.server.configuration.responseCompression = .enabled
    // app.http.server.configuration.requestDecompression = .enabled

    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.middleware.use(ErrorMiddleware())

    // The default is 1 and there is one eventloop per system core by default.
    // Each process (analysis, reconcile etc - a total of 5, see app.yml) contributes to this count.
    // Our current dev setup has 1 vm with 2 cores -> 10n connections max with a db connection limit of 55.
    // Our current prod setup has 3 vms with 4 cores -> 60n connections max with a db connection limit of 105.
    // It should be safe to set this to n=3 even though the theoretical max on prod is then higher than the supported
    // max, because these wouldn't be utilised across all three nodes at the same time. And even if they are,
    // the failure mode is exactly the same we have before increasing the limits.
    // This parameter could also be made configurable via an env variable.
    let maxConnectionsPerEventLoop = 3

    // Setup database connection
    guard
        let host = databaseHost ?? Environment.get("DATABASE_HOST"),
        let port = databasePort ?? Environment.get("DATABASE_PORT").flatMap(Int.init),
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

    let useTLS = Environment.get("DATABASE_USE_TLS").flatMap(\.asBool) ?? false
    let tlsConfig: PostgresConnection.Configuration.TLS = useTLS ? .require(try .init(configuration: .clientDefault)) : .disable
    let dbConfig = SQLPostgresConfiguration(hostname: host, port: port, username: username, password: password, database: database, tls: tlsConfig)
    app.databases.use(.postgres(configuration: dbConfig,
                                maxConnectionsPerEventLoop: maxConnectionsPerEventLoop,
                                // See https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2227
                                // for details why we've changed this from the default of 10s.
                                connectionPoolTimeout: .seconds(20),
                                // Set sqlLogLevel to .info to log SQL queries with the default log level.
                                sqlLogLevel: .debug),
                      as: .psql)

    AllMigrations.register(on: app.migrations)

    app.asyncCommands.use(Analyze.Command(), as: "analyze")
    app.asyncCommands.use(BuildBacklogStats.Command(), as: "build-backlog-stats")
    app.asyncCommands.use(CreateRestfileCommand(), as: "create-restfile")
    app.asyncCommands.use(DeleteBuildsCommand(), as: "delete-builds")
    app.asyncCommands.use(Ingestion.Command(), as: "ingest")
    app.asyncCommands.use(ReconcileCommand(), as: "reconcile")
    app.asyncCommands.use(TriggerBuildsCommand(), as: "trigger-builds")
    app.asyncCommands.use(ReAnalyzeVersions.Command(), as: "re-analyze-versions")
    app.asyncCommands.use(Alerting.Command(), as: "alerting")

    // register routes
    try routes(app)

    // bootstrap app metrics
    @Dependency(\.metricsSystem) var metricsSystem
    metricsSystem.bootstrap()
}
