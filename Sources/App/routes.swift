import Fluent
import Vapor


func routes(_ app: Application) throws {
    app.get { req in
        HomeIndex.Model.query(database: req.db).map { HomeIndex.View($0).document() }
    }

    app.get(.path(for: Root.privacy)) { _ in MarkdownPage("privacy.md").document() }

    let packageController = PackageController()
    app.get(.path(for: Root.packages), use: packageController.index)
    app.get(.path(for: Root.package(.name("id"))), use: packageController.show)

    do {  // admin
        app.get(.path(for: Root.admin)) { req in PublicPage.admin() }
    }

    do {  // api
        app.get(Root.api(.version).pathComponents) { req in API.Version(version: appVersion) }
        app.get(Root.api(.search).pathComponents, use: API.SearchController.get)

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
