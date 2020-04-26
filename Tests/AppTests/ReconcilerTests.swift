@testable import App

import Vapor
import XCTest


class ReconcilerTests: XCTestCase {
    var app: Application!

    override func setUpWithError() throws {
        app = try setup(.testing)
    }

    override func tearDownWithError() throws {
        app.shutdown()
    }

    func test_basic_reconciliation() throws {
        let urls = [
            "https://github.com/finestructure/Gala",
            "https://github.com/finestructure/Rester",
            "https://github.com/finestructure/SwiftPMLibrary-Server"
        ]
        Current.fetchMasterPackageList = { _ in mockFetchMasterPackageList(urls) }

        try reconcile(with: app.client, database: app.db).wait()

        let packages = try Package.query(on: app.db).all().wait()
        XCTAssertEqual(packages.map(\.url).sorted(), urls.sorted())
        packages.forEach {
            XCTAssertNotNil($0.id)
            XCTAssertNotNil($0.createdAt)
            XCTAssertNotNil($0.updatedAt)
        }
    }
}
