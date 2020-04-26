@testable import App

import Vapor
import XCTest


class IngestorTests: XCTestCase {
    var app: Application!

    override func setUpWithError() throws {
        app = try setup(.testing)
    }

    override func tearDownWithError() throws {
        app.shutdown()
    }

    func test_basic_ingestiong() throws {
        let urls = [
            "https://github.com/finestructure/Gala",
            "https://github.com/finestructure/Rester",
            "https://github.com/finestructure/SwiftPMLibrary-Server"
        ]
        Current.fetchMasterPackageList = { _ in mockFetchMasterPackageList(urls) }


    }

}
