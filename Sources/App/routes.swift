import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req in
        return "It works!"
    }

    app.get("hello") { req -> String in
        return "Hello, world!"
    }

    let controller = PackageController()
    app.get("packages", use: controller.index)
    app.get("packages", ":id", use: controller.get)
    app.post("packages", use: controller.create)
    app.put("packages", ":id", use: controller.replace)
    app.delete("packages", ":id", use: controller.delete)

    app.get("packages", "run", ":command", use: controller.run)
}
