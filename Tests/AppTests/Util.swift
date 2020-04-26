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


func mockFetchMasterPackageList(_ urls: [String]) -> EventLoopFuture<[URL]> {
    EmbeddedEventLoop().makeSucceededFuture(urls.compactMap(URL.init(string:)))
}
