// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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

import Fluent
import Foundation
import Plot

struct RSSFeed {
    var title: String
    var description: String
    var link: String
    var items: [Node<RSS.ChannelContext>]

    var rss: RSS {
        RSS(
            .title(title),
            .description(description),
            .link(link),
            //  .language(language),
            //  .lastBuildDate(date, timeZone: context.dateFormatter.timeZone),
            //  .pubDate(date, timeZone: context.dateFormatter.timeZone),
            .ttl(Int(Constants.rssTTL.inMinutes)),
            .atomLink(link),
            .group(items)
        )
    }
}

extension RSSFeed {
    static func recentPackages(on database: Database,
                               limit: Int = Constants.rssFeedMaxItemCount) -> EventLoopFuture<Self> {
        RecentPackage.fetch(on: database, limit: limit)
            .mapEach(\.rssItem)
            .map {
                RSSFeed(title: "Swift Package Index – Recently Added",
                        description: "List of recently added Swift packages",
                        link: SiteURL.rssPackages.absoluteURL(),
                        items: $0)
            }
    }

    static func recentReleases(on database: Database,
                               limit: Int = Constants.rssFeedMaxItemCount,
                               filter: RecentRelease.Filter = .all) -> EventLoopFuture<Self> {
        RecentRelease.fetch(on: database, limit: limit, filter: filter)
            .mapEach(\.rssItem)
            .map {
                RSSFeed(title: "Swift Package Index – Recent Releases",
                        description: "List of recent Swift packages releases",
                        link: SiteURL.rssReleases.absoluteURL(),
                        items: $0)
            }
    }
}

extension RecentPackage {
    var rssGuid: String {
        "\(repositoryOwner)/\(repositoryName)"
    }

    var rssItem: Node<RSS.ChannelContext> {
        let link = SiteRoute.absoluteURL(for: .package(owner: repositoryOwner, repository: repositoryName))
        return .item(
            .guid(.text(rssGuid), .isPermaLink(false)),
            .title(packageName),
            .link(link),
            .pubDate(createdAt, timeZone: .utc),
            .description(
                .p(.text(packageSummary ?? "")),
                .small(
                    .a(
                        .href(link),
                        .text("\(repositoryOwner)/\(repositoryName)")
                    )
                )
            )
        )
    }
}

extension RecentRelease {
    var rssGuid: String {
        "\(repositoryOwner)/\(repositoryName)/\(version)"
    }

    var rssItem: Node<RSS.ChannelContext> {
        let packageUrl = SiteRoute.absoluteURL(for: .package(owner: repositoryOwner, repository: repositoryName))
        let releasesUrl = SiteRoute.absoluteURL(for: .package(owner: repositoryOwner, repository: repositoryName), anchor: "releases")

        func layout(_ body: Node<HTML.BodyContext>) -> Node<HTML.BodyContext> {
            .div(
                .p(
                    .a(
                        .href(packageUrl),
                        .text(packageName)
                    ),
                    .text(" – "),
                    .a(
                        .href(releasesUrl),
                        .text("Version \(version) ")
                    )
                ),
                body,
                .small(
                    .a(
                        .href(packageUrl),
                        .text("\(repositoryOwner)/\(repositoryName)")
                    )
                )
            )
        }

        return .item(
            .guid(.text(rssGuid), .isPermaLink(false)),
            .title("\(packageName) - \(version)"),
            .link(packageUrl),
            .pubDate(releasedAt, timeZone: .utc),
            .description(
                layout(
                    .p(.text(packageSummary ?? ""))
                )
            ),
            .unwrap(releaseNotesHTML) { notes in
                .content(
                    layout(
                        .div(.raw(notes))
                    )
                )
            }
        )
    }
}
