import Vapor

@testable import App

func setup(_ environment: Environment, resetDb: Bool = true) throws -> Application {
    let app = Application(.testing)
    try configure(app)
    if resetDb {
        try app.autoRevert().wait()
        try app.autoMigrate().wait()
    }
    return app
}


extension String {
    var url: URL {
        URL(string: self)!
    }
}
