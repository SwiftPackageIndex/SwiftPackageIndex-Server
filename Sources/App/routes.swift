import Fluent
import Plot
import Vapor


func routes(_ app: Application) throws {
    app.get { req in
        HomeIndex.Model.query(database: req.db).map {
            HomeIndex.View(path: req.url.path, model: $0).document()
        }
    }
    
    app.get(SiteURL.privacy.pathComponents) { req in
        MarkdownPage(path: req.url.path, "privacy.md").document()
    }
    
    app.get(SiteURL.faq.pathComponents) { req in
        MarkdownPage(path: req.url.path, "faq.md").document()
    }
    
    app.get(SiteURL.addAPackage.pathComponents) { req in
        MarkdownPage(path: req.url.path, "add-a-package.md").document()
    }

    app.get(SiteURL.docs(.builds).pathComponents) { req in
        MarkdownPage(path: req.url.path, "docs/builds.md").document()
    }

    let packageController = PackageController()
    app.get(SiteURL.package(.key, .key, .none).pathComponents, use: packageController.show)
    app.get(SiteURL.package(.key, .key, .builds).pathComponents, use: packageController.builds)

    let buildController = BuildController()
    app.get(SiteURL.builds(.key).pathComponents, use: buildController._show)
    app.get(SiteURL.builds(.key).pathComponents + ["s3"], use: buildController.showS3)

    do {  // api

        // public routes
        app.get(SiteURL.api(.version).pathComponents) { req in API.Version(version: appVersion) }
        app.get(SiteURL.api(.search).pathComponents, use: API.SearchController.get)
        app.get(SiteURL.api(.packages(.key, .key, .badge)).pathComponents,
                use: API.PackageController().badge)

        // protected routes
        app.group(User.TokenAuthenticator(), User.guardMiddleware()) { protected in
            let builds = API.BuildController()
            protected.on(.POST, SiteURL.api(.versions(.key, .builds)).pathComponents,
                         body: .collect(maxSize: 100_000),
                         use: builds.create)
            protected.post(SiteURL.api(.versions(.key, .triggerBuild)).pathComponents,
                           use: builds.trigger)
            let packages = API.PackageController()
            protected.post(SiteURL.api(.packages(.key, .key, .triggerBuilds)).pathComponents,
                           use: packages.trigger)
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
}
