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
import Testing


extension AllTests.MastodonTests {

    @Test func apiURL() throws {
        let url = try Mastodon.apiURL(with: "message")
        #expect(url.contains("visibility=unlisted"), "was: \(url)")
    }

    @Test func endToEnd() async throws {
        let message = QueueIsolated<String?>(nil)
        try await withDependencies {
            $0.environment.allowSocialPosts = { true }
            $0.environment.loadSPIManifest = { _ in nil }
            $0.fileManager.fileExists = { @Sendable _ in true }
            $0.git.commitCount = { @Sendable _ in 12 }
            $0.git.firstCommitDate = { @Sendable _ in .t0 }
            $0.git.getTags = { @Sendable _ in [Reference.tag(1, 2, 3)] }
            $0.git.hasBranch = { @Sendable _, _ in true }
            $0.git.lastCommitDate = { @Sendable _ in .t2 }
            $0.git.revisionInfo = { @Sendable _, _ in .init(commit: "sha", date: .t0) }
            $0.git.shortlog = { @Sendable _ in
                """
                10\tPerson 1
                 2\tPerson 2
                """
            }

            $0.github.fetchLicense = { @Sendable _, _ in nil }
            $0.github.fetchMetadata = { @Sendable owner, repository in .mock(owner: owner, repository: repository) }
            $0.github.fetchReadme = { @Sendable _, _ in nil }
            $0.httpClient.mastodonPost = { @Sendable msg in
                if message.value == nil {
                    message.setValue(msg)
                } else {
                    Issue.record("message must only be set once")
                }
            }
            $0.shell.run = { @Sendable cmd, path in
                if cmd.description.hasSuffix("swift package dump-package") {
                    return #"{ "name": "Mock", "products": [], "targets": [] }"#
                }
                return ""
            }
        } operation: {
            try await withApp { app in
                // setup
                let url = "https://github.com/foo/bar"

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
                        let msg = try #require(message.value)
                        #expect(msg.hasPrefix("📦 foo just added a new package, Mock"), "was \(msg)")
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
                #expect(message.value == nil)

                // Now simulate receiving a package update: version 2.0.0
                try await withDependencies {
                    $0.git.getTags = { @Sendable _ in [.tag(2, 0, 0)] }
                } operation: {
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
                    let msg = try #require(message.value)
                    #expect(msg.hasPrefix("⬆️ foo just released Mock v2.0.0"), "was: \(msg)")
                }
            }
        }
    }

}
