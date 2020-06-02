import Fluent
import Vapor


func routes(_ app: Application) throws {
    app.get { req in
        HomeIndex.Model.query(database: req.db).map { HomeIndex.View($0).document() }
    }

    app.get(SiteURL.privacy.pathComponents) { _ in MarkdownPage("privacy.md").document() }

    let packageController = PackageController()
    app.get(SiteURL.packages.pathComponents, use: packageController.index)
    app.get(SiteURL.package(.name("id")).pathComponents, use: packageController.show)

    app.get(SiteURL._package(.name("owner"), .name("repository")).pathComponents, use: packageController._show)

    do {  // admin
        // sas: 2020-06-01: disable admin page until we have an auth mechanism
        //  app.get(Root.admin.pathComponents) { req in PublicPage.admin() }
    }

    do {  // api
        app.get(SiteURL.api(.version).pathComponents) { req in API.Version(version: appVersion) }
        app.get(SiteURL.api(.search).pathComponents, use: API.SearchController.get)

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
}
