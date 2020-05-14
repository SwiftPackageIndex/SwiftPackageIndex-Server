@testable import App

import XCTVapor


class ErrorReportingTests: AppTestCase {

    func test_Rollbar_createItem() throws {
        Current.rollbarToken = { "token" }
        let client = MockClient { $0.status = .ok }
        try Rollbar.createItem(client: client, level: .critical, message: "Test critical").wait()
    }

    func test_recordIngestionError() throws {
        var reportedLevel: AppError.Level? = nil
        var reportedError: AppError? = nil
        Current.reportError = { _, level, error in
            reportedLevel = level
            reportedError = error as? AppError
            return .just(value: ())
        }
        try recordIngestionError(client: app.client, database: app.db, error: AppError.invalidPackageUrl(nil, "foo")).wait()
        XCTAssertEqual(reportedError, AppError.invalidPackageUrl(nil, "foo"))
        XCTAssertEqual(reportedLevel, .error)
    }

}
