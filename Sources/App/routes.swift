import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { _ in HomeIndex().document() }

    let packageController = PackageController()
    app.get("packages", use: packageController.index)
    app.get("packages", ":id", use: packageController.show)

    app.group("admin") { admin in
        admin.get { req in PublicPage.admin() }
    }

    app.group("api") { api in
        api.get("version") { req in API.Version(version: appVersion) }

        let apiPackageController = API.PackageController()
        api.get("packages", use: apiPackageController.index)
        api.get("packages", ":id", use: apiPackageController.get)
        api.post("packages", use: apiPackageController.create)
        api.put("packages", ":id", use: apiPackageController.replace)
        api.delete("packages", ":id", use: apiPackageController.delete)

        api.get("packages", "run", ":command", use: apiPackageController.run)
    }
}
