@testable import App

import XCTVapor


class ErrorReportingTests: AppTestCase {

    func test_recordError() throws {
        try resetDb(app)
        let pkg = try savePackage(on: app.db, "1")
        try recordError(database: app.db,
                        error: AppError.invalidPackageUrl(pkg.id, "foo"),
                        stage: .ingestion).wait()
        do {
            let pkg = try fetch(id: pkg.id, on: app.db)
            XCTAssertEqual(pkg.status, .invalidUrl)
            XCTAssertEqual(pkg.processingStage, .ingestion)
        }
    }

    func test_Rollbar_createItem() throws {
        Current.rollbarToken = { "token" }
        let client = MockClient { _, resp in resp.status = .ok }
        try Rollbar.createItem(client: client, level: .critical, message: "Test critical").wait()
    }

    func test_Ingestor_error_reporting() throws {
        try resetDb(app)
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
        try ingest(application: app, database: app.db, limit: 10).wait()

        // validation
        XCTAssertEqual(reportedError, AppError.invalidPackageUrl(nil, "foo"))
        XCTAssertEqual(reportedLevel, .error)
    }

    func test_Analyzer_error_reporting() throws {
        // setup
        try savePackages(on: app.db, ["1", "2"].asGithubUrls.asURLs, processingStage: .ingestion)
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

    func test_invalidPackageCachePath() throws {
        try resetDb(app)
        // setup
        try savePackages(on: app.db, ["1", "2"], processingStage: .ingestion)

        // MUT
        try analyze(application: app, limit: 10).wait()

        // validation
        let packages = try Package.query(on: app.db).sort(\.$url).all().wait()
        XCTAssertEqual(packages.map(\.status), [.invalidCachePath, .invalidCachePath])
    }

    func test_AppError_Level_Comparable() throws {
        XCTAssert(AppError.Level.critical > .error)
        XCTAssert(AppError.Level.error <= .critical)
        XCTAssert(AppError.Level.error <= .error)
    }

}
