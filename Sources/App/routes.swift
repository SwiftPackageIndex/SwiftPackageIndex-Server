import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req in
        homePage()
    }

    app.group("api") { api in
        let controller = API.PackageController()
        api.get("packages", use: controller.index)
        api.get("packages", ":id", use: controller.get)
        api.post("packages", use: controller.create)
        api.put("packages", ":id", use: controller.replace)
        api.delete("packages", ":id", use: controller.delete)

        api.get("packages", "run", ":command", use: controller.run)
    }
}
