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
import SemanticVersion
import XCTVapor


final class MastodonTests: AppTestCase {

    func test_endToEnd() async throws {
        let message = QueueIsolated<String?>(nil)
        try await withDependencies {
            $0.environment.allowSocialPosts = { true }
            $0.environment.mastodonPost = { @Sendable _, msg in
                if message.value == nil {
                    message.setValue(msg)
                } else {
                    XCTFail("message must only be set once")
                }
            }
        } operation: {
            // setup
            let url = "https://github.com/foo/bar"
            Current.fetchMetadata = { _, owner, repository in .mock(owner: owner, repository: repository) }

            Current.git.commitCount = { @Sendable _ in 12 }
            Current.git.firstCommitDate = { @Sendable _ in .t0 }
            Current.git.lastCommitDate = { @Sendable _ in .t2 }
            Current.git.getTags = { @Sendable _ in [Reference.tag(1, 2, 3)] }
            Current.git.hasBranch = { @Sendable _, _ in true }
            Current.git.revisionInfo = { @Sendable _, _ in .init(commit: "sha", date: .t0) }
            Current.git.shortlog = { @Sendable _ in
            """
            10\tPerson 1
             2\tPerson 2
            """
            }

            Current.shell.run = { @Sendable cmd, path in
                if cmd.description.hasSuffix("swift package dump-package") {
                    return #"{ "name": "Mock", "products": [], "targets": [] }"#
                }
                return ""
            }

            try await withDependencies {
                $0.date.now = .now
                $0.packageListRepository.fetchPackageList = { @Sendable _ in [url.url] }
                $0.packageListRepository.fetchPackageDenyList = { @Sendable _ in [] }
                $0.packageListRepository.fetchCustomCollections = { @Sendable _ in [] }
                $0.packageListRepository.fetchCustomCollection = { @Sendable _, _ in [] }
            } operation: {
                // run first two processing steps
                try await reconcile(client: app.client, database: app.db)
                try await Ingestion.ingest(client: app.client, database: app.db, mode: .limit(10))

                // MUT - analyze, triggering the post
                try await Analyze.analyze(client: app.client,
                                          database: app.db,
                                          mode: .limit(10))

                do {
                    let msg = try XCTUnwrap(message.value)
                    XCTAssertTrue(msg.hasPrefix("📦 foo just added a new package, Mock"), "was \(msg)")
                }

                // run stages again to simulate the cycle...
                message.setValue(nil)
                try await reconcile(client: app.client, database: app.db)
            }

            try await withDependencies {
                $0.date.now = .now.addingTimeInterval(Constants.reIngestionDeadtime)
            } operation: {
                try await Ingestion.ingest(client: app.client, database: app.db, mode: .limit(10))

                // MUT - analyze, triggering posts if any
                try await Analyze.analyze(client: app.client,
                                          database: app.db,
                                          mode: .limit(10))
            }

            // validate - there are no new posts to send
            XCTAssertNil(message.value)

            // Now simulate receiving a package update: version 2.0.0
            Current.git.getTags = { @Sendable _ in [.tag(2, 0, 0)] }

            try await withDependencies {
                // fast forward our clock by the deadtime interval again (*2) and re-ingest
                $0.date.now = .now.addingTimeInterval(Constants.reIngestionDeadtime * 2)
            } operation: {
                try await Ingestion.ingest(client: app.client, database: app.db, mode: .limit(10))
                // MUT - analyze again
                try await Analyze.analyze(client: app.client,
                                          database: app.db,
                                          mode: .limit(10))
            }

            // validate
            let msg = try XCTUnwrap(message.value)
            XCTAssertTrue(msg.hasPrefix("⬆️ foo just released Mock v2.0.0"), "was: \(msg)")
        }
    }

}
