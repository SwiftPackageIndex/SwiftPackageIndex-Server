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

import Dependencies
import Ink
import Plot
import Yams


enum BlogActions {

    struct Model {

        static var blogIndexYmlPath: String {
            @Dependency(\.fileManager) var fileManager
            return fileManager.workingDirectory().appending("Resources/Blog/posts.yml")
        }

        struct PostSummary: Equatable {
            var slug: String
            var title: String
            var summary: String
            var publishedAt: Date
            var published: Bool
        }

        var summaries: [PostSummary]

        init() throws {
            let allSummaries = try Self.allSummaries()

            @Dependency(\.environment) var environment
            summaries = if environment.current() == .production {
                // Only "published" posts show in production.
                allSummaries.filter { $0.published }
            } else {
                // Show *everything* in development and on staging.
                allSummaries
            }
        }

        init(summaries: [PostSummary]) {
            self.summaries = summaries
        }

        var blogDescription: String {
            """
            Find news and updates from the Swift Package Index on our blog. Read more about the
            latest features, our efforts in the community, and any other updates that affect the site.
            """
        }

        static func allSummaries() throws -> [PostSummary] {
            @Dependency(\.fileManager) var fileManager
            guard let data = fileManager.contents(atPath: Self.blogIndexYmlPath) else {
                throw AppError.genericError(nil, "failed to read posts.yml")
            }

            // Post order should be as exists in the file, but reversed.
            return try YAMLDecoder().decode([PostSummary].self, from: String(decoding: data, as: UTF8.self))
                .reversed()
        }

    }
}

extension BlogActions.Model.PostSummary {

    var postMarkdown: String {
        @Dependency(\.fileManager) var fileManager
        let markdownPath = fileManager.workingDirectory()
            .appending("Resources/Blog/Posts/")
            .appending(slug)
            .appending(".md")
        if let markdownData = fileManager.contents(atPath: markdownPath),
           let markdown = String(data: markdownData, encoding: .utf8)
        {
            let parsedMarkdown = MarkdownParser().parse(markdown)
            let html = parsedMarkdown.html
            return html
        } else {
            return "The Markdown for \(slug) is not available."
        }
    }

    func publishInformation() -> Plot.Node<HTML.BodyContext> {
        if published {
            return .publishedTime(publishedAt, label: "Published on")
        } else {
            return .group(
                .strong("DRAFT POST"),
                .text(" – "),
                .publishedTime(publishedAt, label: "Dated")
            )
        }
    }

    func postUrl() -> SiteURL {
        SiteURL.blogPost(.value(slug))
    }

}

extension BlogActions.Model.PostSummary: Decodable {

    enum CodingKeys: String, CodingKey {
        case slug
        case title
        case summary
        case publishedAt = "published_at"
        case published
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.slug = try container.decode(String.self, forKey: .slug)
        self.title = try container.decode(String.self, forKey: .title)
        self.summary = try container.decode(String.self, forKey: .summary)
        self.published = try container.decode(Bool.self, forKey: .published)

        let dateString = try container.decode(String.self, forKey: .publishedAt)
        guard let date = DateFormatter.yearMonthDayDateFormatter.date(from: dateString) else {
            throw DecodingError.dataCorruptedError(forKey: .publishedAt, in: container,
                                                   debugDescription: "Could not parse the publish date for \(slug)")
        }
        self.publishedAt = date
    }
}
