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

import Foundation

@testable import App

import Dependencies
import Testing


extension AllTests.BlogActionsModelTests {

    @Test func init_loadSummaries() async throws {
        try withDependencies {
            $0.fileManager.contents = { @Sendable _ in
                """
                - slug: post-1
                  title: Blog post title one
                  summary: Summary of blog post one
                  published_at: 2024-01-01
                  published: true
                - slug: post-2
                  title: Blog post title two
                  summary: Summary of blog post two
                  published_at: 2024-01-02
                  published: false
                """.data(using: .utf8)
            }
            $0.timeZone = .utc
        } operation: {
            try withDependencies {  // Ensure dev shows all summaries
                $0.environment.current = { .development }
            } operation: {
                // MUT
                let summaries = try BlogActions.Model().summaries

                #expect(summaries.count == 2)
                #expect(summaries.map(\.slug) == ["post-2", "post-1"])
                #expect(summaries.map(\.published) == [false, true])

                // Note that we are testing that the first item in this list is the *last* item in the source YAML
                // as the init should reverse the order of posts so that they display in reverse chronological order
                #expect(summaries.first == BlogActions.Model.PostSummary(
                    slug: "post-2",
                    title: "Blog post title two",
                    summary: "Summary of blog post two",
                    publishedAt: DateFormatter.yearMonthDayDateFormatter.date(from: "2024-01-02")!,
                    published: false)
                )
            }

            try withDependencies {  // Ensure prod shows only published summaries
                $0.environment.current = { .production }
            } operation: {
                // MUT
                let summaries = try BlogActions.Model().summaries

                // validate
                #expect(summaries.map(\.slug) == ["post-1"])
                #expect(summaries.map(\.published) == [true])
            }
        }
    }

    @Test func postSummary_postMarkdown_load() async throws {
        withDependencies {
            $0.fileManager.contents = { @Sendable _ in
                """
                This is some Markdown with [a link](https://example.com) and some _formatting_.
                """.data(using: .utf8)
            }
        } operation: {
            let summary = BlogActions.Model.PostSummary.mock()

            // MUT
            let markdown = summary.postMarkdown

            #expect(markdown == "<p>This is some Markdown with <a href=\"https://example.com\">a link</a> and some <em>formatting</em>.</p>")
        }
    }

    @Test func decode_posts_yml() async throws {
        // setup
        try withDependencies {
            $0.fileManager.contents = FileManagerClient.liveValue.contents(atPath:)
            $0.timeZone = .utc
        } operation: {
            // MUT
            let summaries = try BlogActions.Model.allSummaries()

            // validate
            #expect(summaries.count > 0)
        }
    }

}
