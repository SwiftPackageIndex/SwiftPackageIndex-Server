import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req in
        render(page: homePage())
    }

    let controller = PackageController()
    app.get("packages", use: controller.index)
    app.get("packages", ":id", use: controller.get)
    app.post("packages", use: controller.create)
    app.put("packages", ":id", use: controller.replace)
    app.delete("packages", ":id", use: controller.delete)

    app.get("packages", "run", ":command", use: controller.run)
}
