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

import XCTest

class BlogActionsModelTests: AppTestCase {

    func test_init_loadSummaries() async throws {
        Current.fileManager.contents = { _ in
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

        // MUT
        let summaries = try BlogActions.Model().summaries

        XCTAssertEqual(summaries.count, 2)
        let firstSummary = try XCTUnwrap(summaries).first

        // Note that we are testing that the first item in this list is the *last* item in the source YAML
        // as the init should reverse the order of posts so that they display in reverse chronological order
        XCTAssertEqual(firstSummary, BlogActions.Model.PostSummary(slug: "post-2",
                                                                   title: "Blog post title two",
                                                                   summary: "Summary of blog post two",
                                                                   publishedAt: DateFormatter.yearMonthDayDateFormatter.date(from: "2024-01-02")!,
                                                                   published: false))
    }

    func test_postSummary_postMarkdown_load() async throws {
        Current.fileManager.contents = { _ in
            """
            This is some Markdown with [a link](https://example.com) and some _formatting_.
            """.data(using: .utf8)
        }
        let summary = BlogActions.Model.PostSummary.mock()

        // MUT
        let markdown = summary.postMarkdown

        XCTAssertEqual(markdown, "<p>This is some Markdown with <a href=\"https://example.com\">a link</a> and some <em>formatting</em>.</p>")
    }

    func test_decode_posts_yml() async throws {
        // setup
        Current.fileManager = .live

        // MUT
        let summaries = try BlogActions.Model.allSummaries()

        // validate
        XCTAssert(summaries.count > 0)
    }

}
