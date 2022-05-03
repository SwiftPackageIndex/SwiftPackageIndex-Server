// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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
import Metrics
import Plot
import Prometheus
import Vapor


func routes(_ app: Application) throws {
    do {  // home page
        app.get { req in
            HomeIndex.Model.query(database: req.db).map {
                HomeIndex.View(path: req.url.path, model: $0).document()
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

    do {  // package pages
        let packageController = PackageController()

        do {  // temporary, hacky docc-proxy
            app.get(":owner", ":repository", ":reference", "documentation") {
                try await packageController.documentation(req: $0, fragment: .documentation)
            }
            app.get(":owner", ":repository", ":reference", "documentation", "**") { try await packageController.documentation(req: $0, fragment: .documentation)
            }
            app.get(":owner", ":repository", ":reference", "css") { try await packageController.documentation(req: $0, fragment: .css)
            }
            app.get(":owner", ":repository", ":reference", "css", "**") { try await packageController.documentation(req: $0, fragment: .css)
            }
            app.get(":owner", ":repository", ":reference", "data") { try await packageController.documentation(req: $0, fragment: .data)
            }
            app.get(":owner", ":repository", ":reference", "data", "**") { try await packageController.documentation(req: $0, fragment: .data)
            }
            app.get(":owner", ":repository", ":reference", "js") { try await packageController.documentation(req: $0, fragment: .js)
            }
            app.get(":owner", ":repository", ":reference", "js", "**") { try await packageController.documentation(req: $0, fragment: .js)
            }
            app.get(":owner", ":repository", ":reference", "theme-settings.json", use: packageController.themeSettings)
        }

        app.get(SiteURL.package(.key, .key, .none).pathComponents,
                use: packageController.show)
        app.get(SiteURL.package(.key, .key, .readme).pathComponents,
                use: packageController.readme)
        app.get(SiteURL.package(.key, .key, .releases).pathComponents,
                use: packageController.releases)
        app.get(SiteURL.package(.key, .key, .builds).pathComponents,
                use: packageController.builds)
        app.get(SiteURL.package(.key, .key, .maintainerInfo).pathComponents,
                use: packageController.maintainerInfo)
    }

    do {  // package collection page
        app.get(SiteURL.packageCollection(.key).pathComponents,
                use: PackageCollectionController().generate)
    }

    do {  // author page
        let authorController = AuthorController()
        app.get(SiteURL.author(.key).pathComponents, use: authorController.show)
    }

    do {  // keyword page
        let controller = KeywordController()
        app.get(SiteURL.keywords(.key).pathComponents, use: controller.show)
    }

    do { // Build monitor page
        let buildMonitorController = BuildMonitorController()
        app.get(SiteURL.buildMonitor.pathComponents, use: buildMonitorController.index)
    }

    do {  // build details page
        let buildController = BuildController()
        app.get(SiteURL.builds(.key).pathComponents, use: buildController.show)
    }

    do {  // search page
        app.get(SiteURL.search.pathComponents, use: SearchController().show)
    }

    do {  // api

        // public routes
        app.get(SiteURL.api(.version).pathComponents) { req in
            API.Version(version: appVersion ?? "Unknown")
        }

        app.get(SiteURL.api(.search).pathComponents, use: API.SearchController.get)
        app.get(SiteURL.api(.packages(.key, .key, .badge)).pathComponents,
                use: API.PackageController().badge)

        if Environment.current == .development {
            app.post(SiteURL.api(.packageCollections).pathComponents,
                     use: API.PackageCollectionController().generate)
        }

        // protected routes
        app.group(User.TokenAuthenticator(), User.guardMiddleware()) { protected in
            let buildController = API.BuildController()
            protected.on(.POST, SiteURL.api(.versions(.key, .builds)).pathComponents,
                         use: buildController.create)
            protected.post(SiteURL.api(.versions(.key, .triggerBuild)).pathComponents,
                           use: buildController.trigger)
            let packageController = API.PackageController()
            protected.post(SiteURL.api(.packages(.key, .key, .triggerBuilds)).pathComponents,
                           use: packageController.triggerBuilds)
        }
        
        // sas: 2020-05-19: shut down public API until we have an auth mechanism
        //  let apiPackageController = API.PackageController()
        //  api.get("packages", use: apiPackageController.index)
        //  api.get("packages", ":id", use: apiPackageController.get)
        //  api.post("packages", use: apiPackageController.create)
        //  api.put("packages", ":id", use: apiPackageController.replace)
        //  api.delete("packages", ":id", use: apiPackageController.delete)
        //
        //  api.get("packages", "run", ":command", use: apiPackageController.run)
    }
    
    do {  // RSS + Sitemap
        app.get(SiteURL.rssPackages.pathComponents) { req in
            RSSFeed.recentPackages(on: req.db, limit: Constants.rssFeedMaxItemCount)
                .map { $0.rss }
        }
        
        app.get(SiteURL.rssReleases.pathComponents) { req -> EventLoopFuture<RSS> in
            var filter: RecentRelease.Filter = []
            for param in ["major", "minor", "patch", "pre"] {
                if let value = req.query[Bool.self, at: param], value == true {
                    filter.insert(.init(param))
                }
            }
            if filter.isEmpty { filter = .all }
            return RSSFeed.recentReleases(on: req.db,
                                          limit: Constants.rssFeedMaxItemCount,
                                          filter: filter)
                .map { $0.rss }
        }
        
        app.get(SiteURL.siteMap.pathComponents) { req in
            SiteMap.fetchPackages(req.db)
                .map(SiteURL.siteMap)
        }
    }

    do {  // Metrics
        app.get("metrics") { req -> EventLoopFuture<String> in
            let promise = req.eventLoop.makePromise(of: String.self)
            try MetricsSystem.prometheus().collect(into: promise)
            return promise.futureResult
        }
    }
}
