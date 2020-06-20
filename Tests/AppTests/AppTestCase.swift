import XCTVapor


class AppTestCase: XCTestCase {
    var app: Application!

    override func setUpWithError() throws {
        try super.setUpWithError()
        app = try setup(.testing, resetDb: false)
    }

    override func tearDownWithError() throws {
        app.shutdown()
        try super.tearDownWithError()
    }

    func reset() throws {
        app.shutdown()
        app = try setup(.testing, resetDb: true)
    }
}


class ResettingAppTestCase: XCTestCase {
    var app: Application!

    override func setUpWithError() throws {
        try super.setUpWithError()
        app = try setup(.testing, resetDb: true)
    }

    override func tearDownWithError() throws {
        app.shutdown()
        try super.tearDownWithError()
    }
}
