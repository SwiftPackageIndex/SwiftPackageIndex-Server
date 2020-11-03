import XCTVapor


class AppTestCase: XCTestCase {
    var app: Application!

    func future<T>(_ value: T) -> EventLoopFuture<T> {
        app.eventLoopGroup.next().future(value)
    }
    
    func future<T>(error: Error) -> EventLoopFuture<T> {
        app.eventLoopGroup.next().future(error: error)
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        app = try setup(.testing)
    }
    
    override func tearDownWithError() throws {
        app.shutdown()
        try super.tearDownWithError()
    }
}
