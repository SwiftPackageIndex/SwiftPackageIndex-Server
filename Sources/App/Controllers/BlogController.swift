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

import Vapor
import Plot

enum BlogController {

    static func index(req: Request) async throws -> HTML {
        BlogActions.Index.View(path: req.url.path, model: try BlogActions.Model()).document()
    }

    static func indexFeed(req: Request) async throws -> RSS {
        let model = try BlogActions.Model()
        let items = model.summaries.map { summary -> Node <RSS.ChannelContext> in
                .item(
                    .guid(
                        .text(summary.postUrl().absoluteURL()),
                        .isPermaLink(true)
                    ),
                    .title(summary.title),
                    .link(summary.postUrl().absoluteURL()),
                    .pubDate(summary.publishedAt, timeZone: .utc),
                    .description(
                        .article(
                            .p(
                                .text(summary.summary)
                            ),
                            .p(
                                .a(
                                    .href(summary.postUrl().absoluteURL()),
                                    "Read the full article..."
                                )
                            )
                        )
                    )
                )
        }

        return RSSFeed(title: "The Swift Package Index Blog",
                       description: model.blogDescription,
                       link: SiteURL.blogFeed.absoluteURL(),
                       items: items).rss
    }

    static func show(req: Request) async throws -> HTML {
        guard let slug = req.parameters.get("slug")
        else { throw Abort(.notFound) }

        let model = try BlogActions.Model()
        if let summary = model.summaries.first(where: { $0.slug == slug }) {
            return BlogActions.Show.View(path: req.url.path,
                                         model: summary).document()
        } else {
            throw Abort(.notFound)
        }
    }

}
