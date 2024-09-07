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

import Fluent
import FluentPostgresDriver
import Vapor

@discardableResult
public func configure(_ app: Application) async throws -> String {
    #if DEBUG && os(macOS)
    // The bundle is only loaded if /Applications/InjectionIII.app exists on the local development machine.
    // Requires InjectionIII 4.7.3 or higher to be loaded for compatibility with Package.swift files.
    // Set a value in the `INJECTION_DAEMON` environment variable and quit the InjectionIII.app to disable injection.
    let _ = Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/macOSInjection.bundle")?.load()
    #endif

    app.logger.component = "server"
    Current.setLogger(app.logger)
    Current.setHTTPClient(app.client)

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
        app.migrations.add(UpdateRepositoryAddReadmeHtmlUrl())
    }
    do {  // Migration 027 - add owner name, owner avatar url, and is in organization metadata to repositories
        app.migrations.add(UpdateRepositoryAddOwnerFields())
    }
    do {  // Migration 028 - change products.type from string to json
        app.migrations.add(UpdateProductType())
    }
    do {  // Migration 029 - add release_notes_html to recent_releases and release_notes_html to versions
        app.migrations.add(UpdateVersionAddReleaseNotesHTML())
        app.migrations.add(UpdateRecentReleases6())
    }
    do {  // Migration 030 - add repositories.keywords
        app.migrations.add(UpdateRepositoryAddKeywords())
    }
    do {  // Migration 031 - add search.keywords
        app.migrations.add(UpdateSearch1())
    }
    do {  // Migration 032 - add [license, stars, last_commit_date] to search
        app.migrations.add(UpdateSearch2())
    }
    do {  // Migration 033 - add resolved_dependencies to versions
        app.migrations.add(UpdateVersionAddResolvedDependencies())
    }
    do {  // Migration 034 - make resolved_dependencies nullable
        app.migrations.add(UpdateVersionResolvedDependenciesNullable())
    }
    do {  // Migration 035 - change builds.pending to triggered
        app.migrations.add(UpdateBuildPendingToTriggered())
    }
    do {  // Migration 036 - make packages.score required
        app.migrations.add(UpdatePackageScoreNotNullable())
    }
    do {  // Migration 037 - make several columns on repositories required
        app.migrations.add(UpdateRepositoryStarsNotNullable())
        app.migrations.add(UpdateRepositoryForksNotNullable())
        app.migrations.add(UpdateRepositoryCommitCountNotNullable())
        app.migrations.add(UpdateRepositoryOpenIssuesNotNullable())
        app.migrations.add(UpdateRepositoryOpenPullRequestsNotNullable())
        app.migrations.add(UpdateRepositoryIsArchivedNotNullable())
        app.migrations.add(UpdateRepositoryIsInOrganizationNotNullable())
    }
    do {  // Migration 038 - add last_activity_at to search
        app.migrations.add(AddLastActivityAtToRepositories())
        app.migrations.add(UpdateSearch3())
    }
    do {  // Migration 039 - rename id to package_id on recent_releases
        app.migrations.add(UpdateRecentReleases7())
    }
    do {  // Migration 040 - add platform_compatibility field
        app.migrations.add(UpdatePackageAppPlatformCompatibility())
    }
    do {  // Migration 041 - add platform_compatibility to search
        app.migrations.add(UpdateSearch4())
    }
    do {  // Migration 042 - increase number of rows in recent_releases and recent_packages
        app.migrations.add(UpdateRecentPackages4())
        app.migrations.add(UpdateRecentReleases8())
    }
    do {  // Migration 043 - add runner_id to builds
        app.migrations.add(UpdateBuildAddRunnerId())
    }
    do {  // Migration 044 - make version fields required
        app.migrations.add(UpdateVersionCommitNotNullable())
        app.migrations.add(UpdateVersionCommitDateNotNullable())
        app.migrations.add(UpdateVersionReferenceNotNullable())
    }
    do {  // Migration 045 - create fuzzystrmatch extension for search
        app.migrations.add(CreateExtensionFuzzyStrMatch())
    }
    do {  // Migration 046 - delete `%-arm` builds
        app.migrations.add(DeleteArmBuilds())
    }
    do {  // Migration 047 - Remove `version_count` from `stats` materialized view.
        app.migrations.add(RemoveVersionCountFromStats())
    }
    do {  // Migration 048 - add repositories.homepage_url
        app.migrations.add(UpdateRepositoryAddHomepageUrl())
    }
    do {  // Migration 049 - add versions.spi_manifest
        app.migrations.add(UpdateVersionAddSPIManifest())
    }
    do {  // Migration 050 - add versions.doc_archives
        app.migrations.add(UpdateVersionAddDocArchives())
    }
    do {  // Migration 051 - remove versions.doc_archives
        app.migrations.add(UpdateVersionRemoveDocArchives())
    }
    do {  // Migration 052 - add versions.doc_archives again
        app.migrations.add(UpdateVersionAddDocArchives2())
    }
    do {  // Migration 053 - adds products.type to search
        app.migrations.add(UpdateSearchAddProductType())
    }
    do {  // Migration 054 - create weighted_keywords view for counting keywords
        app.migrations.add(CreateWeightedKeywords())
    }
    do {  // Migration 055 - adds boolean flag indicating existence of docs to search
        app.migrations.add(UpdateSearchAddHasDocs())
    }
    do {  // Migration 056 - reset versions.doc_archives to NULL
        app.migrations.add(ResetDocArchives())
    }
    do {  // Migration 057 - adds boolean flag indicating whether the package contains binary targets
        app.migrations.add(UpdateVersionAddHasBinaryTargets())
    }
    do {  // Migration 058 - adds tsvector to materialised search view
        app.migrations.add(UpdateSearchAddTSVector())
    }
    do {  // Migration 059 - delete Swift 5.3 builds
        app.migrations.add(DeleteSwift5_3Builds())
    }
    do { // Migration 060 - update repository authors type
        app.migrations.add(UpdateRepositoryAuthorsType())
    }
    do { // Migration 061 - create doc_uploads
        app.migrations.add(CreateDocUpload())
    }
    do { // Migration 062 - add repository name to ts vector
        app.migrations.add(UpdateSearchExtendTSVector())
    }
    do { // Migration 063 - add product names to search view
        app.migrations.add(UpdateSearchAddProductNames())
    }
    do { // Migration 064 - add type to targets
        app.migrations.add(UpdateTargetAddType())
    }
    do { // Migration 065 - add linkable_paths_count to doc_uploads
        app.migrations.add(UpdateDocUploadAddLinkablePathsCount())
    }
    do { // Migration 066 - add virtual macro product type to search view
        app.migrations.add(UpdateSearchAddMacroProductType())
    }
    do { // Migration 067 - remove readmeUrl, readmeHtmlUrl from repositories, add readmeEtag
        app.migrations.add(UpdateRepositoryReadmeChanges())
    }
    do { // Migration 068 - add product_dependencies to versions
        app.migrations.add(UpdateVersionAddProductDependencies())
    }
    do { // Migration 069 - add builder_version to builds
        app.migrations.add(UpdateBuildAddBuilderVersion())
    }
    do { // Migration 070 - Add score_details to packages
        app.migrations.add(UpdatePackageAddScoreDetails())
    }
    do { // Migraation 071 - Remove default from product_dependencies, reset product_dependencies and resolved_dependencies
        app.migrations.add(UpdateVersionResetProductDependenciesWithDefault())
        app.migrations.add(UpdateVersionResetResolvedDependencies())
    }
    do { // Migration 072 - Update has_docs to include external documentation
        app.migrations.add(UpdateSearchUpdateHasDocs())
    }
    do { // Migration 073 - Add `funding` JSON field to `repositories`
        app.migrations.add(AddFundingToRepositories())
    }
    do { // Migration 074 - Add `build_duration` field to `builds`
        app.migrations.add(UpdateBuildAddBuildDuration())
    }
    do { // Migration 075 - Reset repositories.funding_links
        app.migrations.add(UpdateRepositoryResetFundingLinks())
    }
    do { // Migration 076 - Add `build_errors` to `builds`
        app.migrations.add(UpdateBuildAddBuildErrors())
    }
    do { // Migration 077 - Remove all etags from README files so they are re-fetched
        app.migrations.add(UpdateRepositoryResetReadmes())
    }
    do { // Migration 078 - Add `build_date` and `commit_hash` to `builds`
        app.migrations.add(UpdateBuildAddBuildDateCommitHash())
    }
    do { // Migration 079 - Add `forked_from` to `repositories`
        app.migrations.add(UpdateRepositoryAddForkedFrom())
    }

    app.asyncCommands.use(Analyze.Command(), as: "analyze")
    app.asyncCommands.use(CreateRestfileCommand(), as: "create-restfile")
    app.asyncCommands.use(DeleteBuildsCommand(), as: "delete-builds")
    app.asyncCommands.use(IngestCommand(), as: "ingest")
    app.asyncCommands.use(ReconcileCommand(), as: "reconcile")
    app.asyncCommands.use(TriggerBuildsCommand(), as: "trigger-builds")
    app.asyncCommands.use(ReAnalyzeVersions.Command(), as: "re-analyze-versions")
    app.asyncCommands.use(Alerting.Command(), as: "alerting")

    // register routes
    try routes(app)

    // bootstrap app metrics
    AppMetrics.bootstrap()

    return host
}
