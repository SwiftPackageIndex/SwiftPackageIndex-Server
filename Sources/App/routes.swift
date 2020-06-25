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

    let packageController = PackageController()
    app.get(SiteURL.packages.pathComponents, use: packageController.index)

    app.get(SiteURL.package(.name("owner"), .name("repository")).pathComponents, use: packageController.show)

    do {  // admin
        // sas: 2020-06-01: disable admin page until we have an auth mechanism
        //  app.get(Root.admin.pathComponents) { req in PublicPage.admin() }
    }

    do {  // api
        app.get(SiteURL.api(.version).pathComponents) { req in API.Version(version: appVersion) }
        app.get(SiteURL.api(.search).pathComponents, use: API.SearchController.get)

        app.group(User.TokenAuthenticator(), User.guardMiddleware()) { protected in
            let builds = API.BuildController()
            protected.post(SiteURL.api(.versions(.name("id"), .builds)).pathComponents,
                           use: builds.create)
            protected.post(SiteURL.api(.versions(.name("id"), .triggerBuild)).pathComponents,
                           use: builds.trigger)
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
