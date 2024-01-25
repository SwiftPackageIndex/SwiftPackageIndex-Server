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
import Plot
import Yams
import Ink

enum BlogActions {

    struct Model {

        struct PostSummary: Equatable {
            var slug: String
            var title: String
            var summary: String
            var publishedAt: Date
            var published: Bool
        }

        var summaries: [PostSummary]

        init() throws {
            let blogIndexYmlPath = Current.fileManager.workingDirectory()
                .appending("Resources/Blog/posts.yml")
            do {
                let allSummaries = if let ymlData = Current.fileManager.contents(atPath: blogIndexYmlPath),
                    let ymlString = String(data: ymlData, encoding: .utf8) {
                        // Post order should be as exists in the file, but reversed.
                        try Array(YAMLDecoder().decode([PostSummary].self, from: ymlString).reversed())
                    } else {
                        Array<PostSummary>()
                    }

                summaries = if Current.environment() == .production {
                    // Only "published" posts show in production.
                    allSummaries.filter { $0.published }
                } else {
                    // Show *everything* in development and on staging.
                    allSummaries
                }
            } catch {
                Current.logger().report(error: error)
                summaries = []
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
    }
}

extension BlogActions.Model.PostSummary {

    var postMarkdown: String {
        let markdownPath = Current.fileManager.workingDirectory()
            .appending("Resources/Blog/Posts/")
            .appending(slug)
            .appending(".md")
        if let markdownData = Current.fileManager.contents(atPath: markdownPath),
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
