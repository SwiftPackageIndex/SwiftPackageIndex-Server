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
import Metrics
import Plot
import Prometheus
import Vapor
import VaporToOpenAPI


func routes(_ app: Application) throws {
    @Dependency(\.environment) var environment

    do {  // home page
        app.get { req in
            if let maintenanceMessage = Current.maintenanceMessage() {
                let model = MaintenanceMessageIndex.Model(markdown: maintenanceMessage)
                return MaintenanceMessageIndex.View(path: req.url.path, model: model).document()
            } else {
                let model = try await HomeIndex.Model.query(database: req.db)
                return HomeIndex.View(path: req.url.path, model: model).document()
            }
        }.excludeFromOpenAPI()
    }

    do {  // static pages
        app.get(SiteURL.addAPackage.pathComponents) { req in
            MarkdownPage(path: req.url.path, "add-a-package.md").document()
        }.excludeFromOpenAPI()

        app.get(SiteURL.docs(.builds).pathComponents) { req in
            MarkdownPage(path: req.url.path, "docs/builds.md").document()
        }.excludeFromOpenAPI()

        app.get(SiteURL.faq.pathComponents) { req in
            MarkdownPage(path: req.url.path, "faq.md").document()
        }.excludeFromOpenAPI()

        app.get(SiteURL.packageCollections.pathComponents) { req in
            MarkdownPage(path: req.url.path, "package-collections.md").document()
        }.excludeFromOpenAPI()

        app.get(SiteURL.privacy.pathComponents) { req in
            MarkdownPage(path: req.url.path, "privacy.md").document()
        }.excludeFromOpenAPI()

        app.get(SiteURL.tryInPlayground.pathComponents) { req in
            MarkdownPage(path: req.url.path, "try-package.md").document()
        }.excludeFromOpenAPI()
    }

    try docRoutes(app)

    do {  // package pages
        app.get(SiteURL.package(.key, .key, .none).pathComponents,
                use: PackageController.show).excludeFromOpenAPI()
        app.get(SiteURL.package(.key, .key, .readme).pathComponents,
                use: PackageController.readme).excludeFromOpenAPI()
        app.get(SiteURL.package(.key, .key, .releases).pathComponents,
                use: PackageController.releases).excludeFromOpenAPI()
        app.get(SiteURL.package(.key, .key, .builds).pathComponents,
                use: PackageController.builds).excludeFromOpenAPI()
        app.get(SiteURL.package(.key, .key, .maintainerInfo).pathComponents,
                use: PackageController.maintainerInfo).excludeFromOpenAPI()

        // Only serve sitemaps in production.
        if environment.current() == .production {
            // Package specific site map, including all documentation URLs if available.
            // Backend reporting currently disabled to avoid reporting costs for metrics we don't need.
            app.group(BackendReportingMiddleware(path: .sitemapPackage, isActive: false)) {
                $0.get(SiteURL.package(.key, .key, .siteMap).pathComponents,
                       use: PackageController.siteMap).excludeFromOpenAPI()
            }
        }
    }

    do {  // package collection pages
        app.get(SiteURL.packageCollectionAuthor(.key).pathComponents,
                use: PackageCollectionController.generate).excludeFromOpenAPI()
        app.get(SiteURL.packageCollectionCustom(.key).pathComponents,
                use: PackageCollectionController.generate).excludeFromOpenAPI()
    }

    do {  // author page
        app.get(SiteURL.author(.key).pathComponents, use: AuthorController.show).excludeFromOpenAPI()
    }

    do {  // keyword page
        app.get(SiteURL.keywords(.key).pathComponents, use: KeywordController.show).excludeFromOpenAPI()
    }

    do { // Blog index, post pages, and feed
        app.get(SiteURL.blog.pathComponents, use: BlogController.index).excludeFromOpenAPI()
        app.get(SiteURL.blogFeed.pathComponents, use: BlogController.indexFeed).excludeFromOpenAPI()
        app.get(SiteURL.blogPost(.key).pathComponents, use: BlogController.show).excludeFromOpenAPI()
    }

    do { // Build monitor page
        app.get(SiteURL.buildMonitor.pathComponents, use: BuildMonitorController.index).excludeFromOpenAPI()
    }

    do {  // Build details page
        app.get(SiteURL.builds(.key).pathComponents, use: BuildController.show).excludeFromOpenAPI()
    }

    do {  // Custom collections page
        app.get(SiteURL.collections(.key).pathComponents, use: CustomCollectionsController.show).excludeFromOpenAPI()
    }

    do {  // Search page
        app.get(SiteURL.search.pathComponents, use: SearchController.show).excludeFromOpenAPI()
    }

    do {  // Supporters
        app.get(SiteURL.supporters.pathComponents, use: SupportersController.show).excludeFromOpenAPI()
    }

    do { // Uptime check
        app.get(SiteURL.uptimeCheck.pathComponents, use: UptimeCheckController.show).excludeFromOpenAPI()
    }

    do {  // spi.yml validation page
        app.get(SiteURL.validateSPIManifest.pathComponents, use: ValidateSPIManifestController.show)
            .excludeFromOpenAPI()
        app.post(SiteURL.validateSPIManifest.pathComponents, use: ValidateSPIManifestController.validate)
            .excludeFromOpenAPI()
    }

    // Ready for Swift 6
    app.get(SiteURL.readyForSwift6.pathComponents, use: ReadyForSwift6Controller.show)
        .excludeFromOpenAPI()

    do {  // OpenAPI spec
        app.get("openapi", "openapi.json") { req in
            req.application.routes.openAPI(
                info: InfoObject(
                    title: "Swift Package Index API",
                    description: "Swift Package Index API",
                    version: "0.1.1"
                )
            )
        }.excludeFromOpenAPI()
    }

    do {  // api

        // public routes
        app.get(SiteURL.api(.version).pathComponents) { req in
            API.Version(version: appVersion ?? "Unknown")
        }
        .openAPI(
            summary: "/api/version",
            description: "Get the site's version.",
            response: .type(of: API.Version(version: "1.2.3")),
            responseContentType: .application(.json)
        )

        app.group(User.APITierAuthenticator(tier: .tier1), User.guardMiddleware()) {
            $0.groupedOpenAPI(auth: .apiBearerToken).group(tags: []) { protected in
                protected.group(BackendReportingMiddleware(path: .search)) {
                    $0.get(SiteURL.api(.search).pathComponents, use: API.SearchController.get)
                        .openAPI(
                            summary: "/api/search",
                            description: "Execute a search.",
                            query: .type(of: API.SearchController.Query.example),
                            response: .type(of: Search.Response.example),
                            responseContentType: .application(.json)
                        )
                }
            }
        }

        // Backend reporting currently disabled to avoid reporting costs for metrics we don't need.
        app.group(BackendReportingMiddleware(path: .badge, isActive: false)) {
            $0.get(SiteURL.api(.packages(.key, .key, .badge)).pathComponents,
                   use: API.PackageController.badge)
            .openAPI(
                summary: "/api/packages/{owner}/{repository}/badge",
                description: "Get shields.io badge for the given repository.",
                query: .type(of: API.PackageController.BadgeQuery.example),
                response: .type(of: Badge.example),
                responseContentType: .application(.json)
            )
        }

        // api token protected routes
         app.group(User.APITierAuthenticator(tier: .tier3), User.guardMiddleware()) {
            $0.groupedOpenAPI(auth: .apiBearerToken).group(tags: []) { protected in
                protected.group(BackendReportingMiddleware(path: .package)) {
                    $0.get("api", "packages", ":owner", ":repository", use: API.PackageController.get)
                        .openAPI(
                            summary: "/api/packages/{owner}/{repository}",
                            description: "Get package details.",
                            response: .type(of: API.PackageController.GetRoute.Model.example),
                            responseContentType: .application(.json)
                        )
                }

                protected.group(BackendReportingMiddleware(path: .packageCollections)) {
                    $0.post(SiteURL.api(.packageCollections).pathComponents,
                            use: API.PackageCollectionController.generate)
                    .openAPI(
                        summary: "/api/package-collections",
                        description: "Generate a signed package collection.",
                        body: .type(of: API.PostPackageCollectionDTO.example),
                        response: .type(of: SignedCollection.example),
                        responseContentType: .application(.json)
                    )
                }

                protected.group(BackendReportingMiddleware(path: .dependencies)) {
                    $0.get(SiteURL.api(.dependencies).pathComponents, use: API.DependencyController.get)
                        .openAPI(
                            summary: "/api/dependencies",
                            description: "Return the full resolved dependencies graph across all packages.",
                            response: .type(of: [API.DependencyController.PackageRecord.example]),
                            responseContentType: .application(.json)
                        )
                }
            }
        }

        // builder token protected routes
        app.group(User.BuilderAuthenticator(), User.guardMiddleware()) {
            $0.groupedOpenAPI(auth: .builderBearerToken).group(tags: []) { protected in
                protected.on(.POST, SiteURL.api(.versions(.key, .buildReport)).pathComponents,
                             body: .collect(maxSize: 100_000),
                             use: API.BuildController.buildReport)
                .openAPI(
                    summary: "/api/versions/{id}/build-report",
                    description: "Send a build report.",
                    body: .type(of: API.PostBuildReportDTO.example),
                    response: .type(HTTPStatus.self),
                    responseContentType: .application(.json)
                )

                protected.on(.POST, SiteURL.api(.builds(.key, .docReport)).pathComponents,
                             body: .collect(maxSize: 100_000),
                             use: API.BuildController.docReport)
                .openAPI(
                    summary: "/api/builds/{id}/doc-report",
                    description: "Send a documentation generation report.",
                    body: .type(of: API.PostDocReportDTO.example),
                    response: .type(HTTPStatus.self),
                    responseContentType: .application(.json)
                )
            }
        }

    }

    do { // RSS
        app.group(BackendReportingMiddleware(path: .rss)) {
            $0.get(SiteURL.rssPackages.pathComponents, use: RSSFeed.showPackages)
                .excludeFromOpenAPI()

            $0.get(SiteURL.rssReleases.pathComponents, use: RSSFeed.showReleases)
                .excludeFromOpenAPI()
        }
    }

    // Only serve sitemaps in production.
    if environment.current() == .production {
        do { // Site map index and static page site map
            app.group(BackendReportingMiddleware(path: .sitemapIndex)) {
                $0.get(SiteURL.siteMapIndex.pathComponents, use: SiteMapController.index)
                    .excludeFromOpenAPI()
            }

            app.group(BackendReportingMiddleware(path: .sitemapStaticPages)) {
                $0.get(SiteURL.siteMapStaticPages.pathComponents, use: SiteMapController.staticPages)
                    .excludeFromOpenAPI()
            }
        }
    }

    do {  // Metrics
        app.get("metrics") { req -> String in
            try await MetricsSystem.prometheus().collect()
        }.excludeFromOpenAPI()
    }
}
