// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@testable import App

import Dependencies
import XCTVapor


class ErrorReportingTests: AppTestCase {

    func test_recordError() async throws {
        let pkg = try await savePackage(on: app.db, "1")
        try await recordError(database: app.db,
                              error: AppError.cacheDirectoryDoesNotExist(pkg.id, "path"),
                              stage: .ingestion)
        do {
            let pkg = try await XCTUnwrapAsync(try await Package.find(pkg.id, on: app.db))
            XCTAssertEqual(pkg.status, .cacheDirectoryDoesNotExist)
            XCTAssertEqual(pkg.processingStage, .ingestion)
        }
    }

    func test_Ingestor_error_reporting() async throws {
        // setup
        try await Package(url: "1", processingStage: .reconciliation).save(on: app.db)
        Current.fetchMetadata = { _, _, _ in throw Github.Error.invalidURI(nil, "1") }

        try await withDependencies {
            $0.date.now = .now
        } operation: {
            // MUT
            try await ingest(client: app.client, database: app.db, mode: .limit(10))
        }

        // validation
        logger.logs.withValue {
            XCTAssertEqual($0, [.init(level: .warning,
                                      message: #"App.Github.Error.invalidURI(nil, "1")"#)])
        }
    }

    func test_Analyzer_error_reporting() async throws {
        // setup
        try await Package(id: .id1, url: "1".asGithubUrl.url, processingStage: .ingestion).save(on: app.db)
        Current.fileManager.fileExists = { @Sendable _ in true }
        Current.shell.run = { @Sendable cmd, path in
            if cmd.description == "git tag" { return "1.0.0" }
            // returning a blank string will cause an exception when trying to
            // decode it as the manifest result - we use this to simulate errors
            return "invalid"
        }

        // MUT
        try await Analyze.analyze(client: app.client,
                                  database: app.db,
                                  mode: .limit(10))

        // validation
        logger.logs.withValue {
            XCTAssertEqual($0, [
                .init(level: .critical, message: "updatePackages: unusually high error rate: 1/1 = 100.0%"),
                .init(level: .warning, message: #"App.AppError.genericError(Optional(\#(UUID.id1)), "updateRepository: no repository")"#)
            ])
        }
    }

    func test_invalidPackageCachePath() async throws {
        // setup
        try await savePackages(on: app.db, ["1", "2"], processingStage: .ingestion)

        // MUT
        try await Analyze.analyze(client: app.client,
                                  database: app.db,
                                  mode: .limit(10))

        // validation
        let packages = try await Package.query(on: app.db).sort(\.$url).all()
        XCTAssertEqual(packages.map(\.status), [.invalidCachePath, .invalidCachePath])
    }

}
