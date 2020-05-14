@testable import App

import XCTVapor


class ErrorReportingTests: AppTestCase {

    func test_Rollbar_createItem() throws {
        Current.rollbarToken = { "token" }
        let client = MockClient { $0.status = .ok }
        try Rollbar.createItem(client: client, level: .critical, message: "Test critical").wait()
    }

    func test_Ingestor_error_reporting() throws {
        // setup
        try savePackages(on: app.db, ["1", "2"], processingStage: .reconciliation)
        Current.fetchMetadata = { _, pkg in .just(error: AppError.invalidPackageUrl(nil, "foo")) }

        var reportedLevel: AppError.Level? = nil
        var reportedError: AppError? = nil
        Current.reportError = { _, level, error in
            reportedLevel = level
            reportedError = error as? AppError
            return .just(value: ())
        }

        // MUT
        try ingest(client: app.client, database: app.db, limit: 10).wait()

        // validation
        XCTAssertEqual(reportedError, AppError.invalidPackageUrl(nil, "foo"))
        XCTAssertEqual(reportedLevel, .error)
    }

    func test_Analyzer_error_reporting() throws {
        // setup
        try savePackages(on: app.db, ["1", "2"].gh.urls, processingStage: .ingestion)
        Current.fileManager.fileExists = { _ in true }
        Current.shell.run = { cmd, path in
            if cmd.string == "git tag" { return "1.0.0" }
            // returning a blank string will cause an exception when trying to
            // decode it as the manifest result - we use this to simulate errors
            return "invalid"
        }

        var reportedLevel: AppError.Level? = nil
        var reportedError: Error? = nil
        Current.reportError = { _, level, error in
            reportedLevel = level
            reportedError = error
            return .just(value: ())
        }

        // MUT
        try analyze(application: app, limit: 10).wait()

        // validation
        XCTAssertNotNil(reportedError)
        XCTAssertEqual(reportedLevel, .error)
    }

}
