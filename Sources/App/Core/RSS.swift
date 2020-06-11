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
            .ttl(Constants.rssTTL),
            .atomLink(link),
            .group(items)
        )
    }

}


extension RSSFeed {
    static func recentPackages(on database: Database,
                               maxItemCount: Int = Constants.rssFeedMaxItemCount) -> EventLoopFuture<Self> {
        RecentPackage.fetch(on: database, limit: maxItemCount)
            .mapEach(\.rssItem)
            .map {
                RSSFeed(title: "Swift Package Index – Recently Added",
                        description: "List of recently added Swift packages",
                        link: SiteURL.rssPackages.absoluteURL(),
                    items: $0)
        }
    }

    static func recentReleases(on database: Database,
                               maxItemCount: Int = Constants.rssFeedMaxItemCount) -> EventLoopFuture<Self> {
        RecentRelease.fetch(on: database, limit: maxItemCount)
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
                                   .value(repositoryName)).absoluteURL()
        return .item(
            .guid(.text(link), .isPermaLink(true)),
            .title(packageName),
            .link(link),
            .pubDate(createdAt, timeZone: .utc),
            .description(
                .p(
                    .a(
                        .href(link),
                        .text(packageName)
                    )
                ),
                .p(.text(packageSummary ?? "")),
                .element(named: "small", nodes: [
                    .a(
                        .href(link),
                        .text("\(repositoryOwner)/\(repositoryName)")
                    )
                ])
            )
        )
    }
}


extension RecentRelease {
    var rssItem: Node<RSS.ChannelContext> {
        let link = SiteURL.package(.value(repositoryOwner),
                                   .value(repositoryName)).absoluteURL(anchor: version)
        return .item(
            .guid(.text(link), .isPermaLink(true)),
            .title("\(packageName) - \(version)"),
            .link(link),
            .pubDate(releasedAt, timeZone: .utc),
            .description(
                .p(
                    .a(
                        .href(link),
                        .text(packageName)
                    ),
                    .element(named: "small", text: " – \(version)")
                ),
                .p(.text(packageSummary ?? "")),
                .element(named: "small", nodes: [
                    .a(
                        .href(link),
                        .text("\(repositoryOwner)/\(repositoryName)")
                    )
                ])
            )
        )
    }
}

// TODO: Upstream to Plot
extension Node where Context: RSSItemContext {
    static func description(_ nodes: Node<HTML.BodyContext>...) -> Node {
        .element(named: "description",
                 nodes: [Node.raw("<![CDATA[\(nodes.render())]]>")])
    }
}
