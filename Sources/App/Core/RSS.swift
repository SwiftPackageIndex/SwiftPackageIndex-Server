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
    var rssItem: Node<RSS.ChannelContext> {
        let link = SiteURL.package(.value(repositoryOwner),
                                   .value(repositoryName),
                                   .none).absoluteURL()
        return .item(
            .guid(.text(link), .isPermaLink(true)),
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
    var rssItem: Node<RSS.ChannelContext> {
        let packageUrl = SiteURL.package(.value(repositoryOwner),
                                         .value(repositoryName),
                                         .none).absoluteURL()
        return .item(
            .guid(.text(packageUrl), .isPermaLink(true)),
            .title("\(packageName) - \(version)"),
            .link(packageUrl),
            .pubDate(releasedAt, timeZone: .utc),
            .description(
                .p(
                    .a(
                        .href(packageUrl),
                        .text(packageName)
                    ),
                    .small(
                        " – ",
                        .a(
                            .href(releaseUrl ?? packageUrl),
                            .text("Version \(version) release notes. ")
                        )
                    )
                ),
                .p(.text(packageSummary ?? "")),
                .small(
                    .a(
                        .href(packageUrl),
                        .text("\(repositoryOwner)/\(repositoryName)")
                    )
                )
            ),
            .content(
                .unwrap(releaseNotes) { notes in
                    .div(
                        .a(
                            .href(releaseUrl ?? packageUrl),
                            .text("Version \(version) release notes. ")
                        ),
                        .div(.raw(notes))
                    )
                }
            )
        )
    }
}
