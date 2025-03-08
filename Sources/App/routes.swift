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


func routes(_ app: Application) throws {
    @Dependency(\.environment) var environment

    do {  // home page
        app.get { req in
            if let maintenanceMessage = environment.maintenanceMessage() {
                let model = MaintenanceMessageIndex.Model(markdown: maintenanceMessage)
                return MaintenanceMessageIndex.View(path: req.url.path, model: model).document()
            } else {
                let model = try await HomeIndex.Model.query(database: req.db)
                return HomeIndex.View(path: req.url.path, model: model).document()
            }
        }
    }

    do {  // static pages
        app.get(SiteURL.addAPackage.pathComponents) { req in
            MarkdownPage(path: req.url.path, "add-a-package.md").document()
        }

        app.get(SiteURL.docs(.builds).pathComponents) { req in
            MarkdownPage(path: req.url.path, "docs/builds.md").document()
        }

        app.get(SiteURL.faq.pathComponents) { req in
            MarkdownPage(path: req.url.path, "faq.md").document()
        }

        app.get(SiteURL.packageCollections.pathComponents) { req in
            MarkdownPage(path: req.url.path, "package-collections.md").document()
        }

        app.get(SiteURL.privacy.pathComponents) { req in
            MarkdownPage(path: req.url.path, "privacy.md").document()
        }

        app.get(SiteURL.tryInPlayground.pathComponents) { req in
            MarkdownPage(path: req.url.path, "try-package.md").document()
        }
    }

    try docRoutes(app)

    do {  // package pages
        app.get(SiteURL.package(.key, .key, .none).pathComponents,
                use: PackageController.show)
        app.get(SiteURL.package(.key, .key, .readme).pathComponents,
                use: PackageController.readme)
        app.get(SiteURL.package(.key, .key, .releases).pathComponents,
                use: PackageController.releases)
        app.get(SiteURL.package(.key, .key, .builds).pathComponents,
                use: PackageController.builds)
        app.get(SiteURL.package(.key, .key, .maintainerInfo).pathComponents,
                use: PackageController.maintainerInfo)

        // Only serve sitemaps in production.
        if environment.current() == .production {
            // Package specific site map, including all documentation URLs if available.
            // Backend reporting currently disabled to avoid reporting costs for metrics we don't need.
            app.group(BackendReportingMiddleware(path: .sitemapPackage, isActive: false)) {
                $0.get(SiteURL.package(.key, .key, .siteMap).pathComponents,
                       use: PackageController.siteMap)
            }
        }
    }

    do {  // package collection pages
        app.get(SiteURL.packageCollectionAuthor(.key).pathComponents,
                use: PackageCollectionController.generate)
        app.get(SiteURL.packageCollectionCustom(.key).pathComponents,
                use: PackageCollectionController.generate)
        app.get(SiteURL.packageCollectionKeyword(.key).pathComponents,
                use: PackageCollectionController.generate)
    }

    do {  // author page
        app.get(SiteURL.author(.key).pathComponents, use: AuthorController.show)
    }

    do {  // keyword page
        app.get(SiteURL.keywords(.key).pathComponents, use: KeywordController.show)
    }

    do { // Blog index, post pages, and feed
        app.get(SiteURL.blog.pathComponents, use: BlogController.index)
        app.get(SiteURL.blogFeed.pathComponents, use: BlogController.indexFeed)
        app.get(SiteURL.blogPost(.key).pathComponents, use: BlogController.show)
    }

    do { // Build monitor page
        app.get(SiteURL.buildMonitor.pathComponents, use: BuildMonitorController.index)
    }

    do {  // Build details page
        app.get(SiteURL.builds(.key).pathComponents, use: BuildController.show)
    }

    do {  // Custom collections page
        app.get(SiteURL.collections(.key).pathComponents, use: CustomCollectionsController.show)
    }

    do {  // Search page
        app.get(SiteURL.search.pathComponents, use: SearchController.show)
    }

    do {  // Supporters
        app.get(SiteURL.supporters.pathComponents, use: SupportersController.show)
    }

    do { // Uptime check
        app.get(SiteURL.healthCheck.pathComponents, use: HealthCheckController.show)
    }

    do {  // spi.yml validation page
        app.get(SiteURL.validateSPIManifest.pathComponents, use: ValidateSPIManifestController.show)
        app.post(SiteURL.validateSPIManifest.pathComponents, use: ValidateSPIManifestController.validate)
    }

    // Ready for Swift 6
    app.get(SiteURL.readyForSwift6.pathComponents, use: ReadyForSwift6Controller.show)

    do {  // api

        // public routes
        app.get(SiteURL.api(.version).pathComponents) { req in
            API.Version(version: appVersion ?? "Unknown")
        }

        app.group(User.APITierAuthenticator(tier: .tier1), User.guardMiddleware()) { protected in
            protected.group(BackendReportingMiddleware(path: .search)) {
                $0.get(SiteURL.api(.search).pathComponents, use: API.SearchController.get)
            }
        }

        // Backend reporting currently disabled to avoid reporting costs for metrics we don't need.
        app.group(BackendReportingMiddleware(path: .badge, isActive: false)) {
            $0.get(SiteURL.api(.packages(.key, .key, .badge)).pathComponents,
                   use: API.PackageController.badge)
        }

        // api token protected routes
        app.group(User.APITierAuthenticator(tier: .tier3), User.guardMiddleware()) { protected in
            protected.group(BackendReportingMiddleware(path: .package)) {
                $0.get("api", "packages", ":owner", ":repository", use: API.PackageController.get)
            }

            protected.group(BackendReportingMiddleware(path: .packageCollections)) {
                $0.post(SiteURL.api(.packageCollections).pathComponents,
                        use: API.PackageCollectionController.generate)
            }

            protected.group(BackendReportingMiddleware(path: .dependencies)) {
                $0.get(SiteURL.api(.dependencies).pathComponents, use: API.DependencyController.get)
            }
        }

        // builder token protected routes
        app.group(User.BuilderAuthenticator(), User.guardMiddleware()) { protected in
            protected.on(.POST, SiteURL.api(.versions(.key, .buildReport)).pathComponents,
                         body: .collect(maxSize: 100_000),
                         use: API.BuildController.buildReport)
            
            protected.on(.POST, SiteURL.api(.builds(.key, .docReport)).pathComponents,
                         body: .collect(maxSize: 100_000),
                         use: API.BuildController.docReport)
        }

    }

    do { // RSS
        app.group(BackendReportingMiddleware(path: .rss)) {
            $0.get(SiteURL.rssPackages.pathComponents, use: RSSFeed.showPackages)
            $0.get(SiteURL.rssReleases.pathComponents, use: RSSFeed.showReleases)
        }
    }

    // Only serve sitemaps in production.
    if environment.current() == .production {
        do { // Site map index and static page site map
            app.group(BackendReportingMiddleware(path: .sitemapIndex)) {
                $0.get(SiteURL.siteMapIndex.pathComponents, use: SiteMapController.index)
            }

            app.group(BackendReportingMiddleware(path: .sitemapStaticPages)) {
                $0.get(SiteURL.siteMapStaticPages.pathComponents, use: SiteMapController.staticPages)
            }
        }
    }

    do {  // Metrics
        app.get("metrics") { req -> String in
            try await MetricsSystem.prometheus().collect()
        }
    }
}
