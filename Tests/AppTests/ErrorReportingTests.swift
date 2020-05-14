@testable import App

import XCTVapor


class ErrorReportingTests: AppTestCase {

    func test_Rollbar_createItem() throws {
        Current.rollbarToken = { "token" }
        let client = MockClient { $0.status = .ok }

        try Rollbar.createItem(client: client, level: .critical, message: "Test critical").wait()
    }

}


