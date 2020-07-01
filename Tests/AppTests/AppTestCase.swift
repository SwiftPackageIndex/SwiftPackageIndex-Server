import XCTVapor


class AppTestCase: XCTestCase {
    var app: Application!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        app = try setup(.testing)
    }
    
    override func tearDownWithError() throws {
        app.shutdown()
        try super.tearDownWithError()
    }
}
