// Copyright 2020-2022 Dave Verwer, Sven A. Schmidt, and other contributors.
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

import XCTVapor
import SemanticVersion


final class MastodonTests: AppTestCase {

    func test_endToEnd() async throws {
        // setup
        var message: String?
        Current.mastodonPost = { _, msg in
            if message == nil {
                message = msg
            } else {
                XCTFail("message must only be set once")
            }
        }

        var tag = Reference.tag(1, 2, 3)
        let url = "https://github.com/foo/bar"
        Current.fetchMetadata = { _, pkg in .mock(for: pkg) }
        Current.fetchPackageList = { _ in [url.url] }

        Current.git.commitCount = { _ in 12 }
        Current.git.firstCommitDate = { _ in .t0 }
        Current.git.lastCommitDate = { _ in .t2 }
        Current.git.getTags = { _ in [tag] }
        Current.git.revisionInfo = { _, _ in .init(commit: "sha", date: .t0) }
        Current.git.shortlog = { _ in
            """
            10\tPerson 1
             2\tPerson 2
            """
        }

        Current.shell.run = { cmd, path in
            if cmd.string.hasSuffix("swift package dump-package") {
                return #"{ "name": "Mock", "products": [], "targets": [] }"#
            }
            return ""
        }
        // run first two processing steps
        try await reconcile(client: app.client, database: app.db)
        try await ingest(client: app.client, database: app.db, logger: app.logger, mode: .limit(10))

        // MUT - analyze, triggering the post
        try await Analyze.analyze(client: app.client,
                                  database: app.db,
                                  logger: app.logger,
                                  mode: .limit(10))
        do {
            let msg = try XCTUnwrap(message)
            XCTAssertTrue(msg.hasPrefix("📦 foo just added a new package, Mock"), "was \(msg)")
        }

        // run stages again to simulate the cycle...
        message = nil
        try await reconcile(client: app.client, database: app.db)
        Current.date = { Date().addingTimeInterval(Constants.reIngestionDeadtime) }
        try await ingest(client: app.client, database: app.db, logger: app.logger, mode: .limit(10))

        // MUT - analyze, triggering tweets if any
        try await Analyze.analyze(client: app.client,
                                  database: app.db,
                                  logger: app.logger,
                                  mode: .limit(10))

        // validate - there are no new tweets to send
        XCTAssertNil(message)

        // Now simulate receiving a package update: version 2.0.0
        tag = .tag(2, 0, 0)
        // fast forward our clock by the deadtime interval again (*2) and re-ingest
        Current.date = { Date().addingTimeInterval(Constants.reIngestionDeadtime * 2) }
        try await ingest(client: app.client, database: app.db, logger: app.logger, mode: .limit(10))

        // MUT - analyze again
        try await Analyze.analyze(client: app.client,
                                  database: app.db,
                                  logger: app.logger,
                                  mode: .limit(10))

        // validate
        let msg = try XCTUnwrap(message)
        XCTAssertTrue(msg.hasPrefix("⬆️ foo just released Mock v2.0.0"), "was: \(msg)")
    }

}
