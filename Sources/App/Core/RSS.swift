import Fluent
import Foundation
import Plot


struct RSSFeed {
    struct Item {
        var node: Node<RSS.ChannelContext>
    }

    var title: String
    var description: String
    var link: String
    var items: [Item]

    var rss: RSS {
        RSS(
            .title(title),
            .description(description),
            .link(link),
            //  .language(language),
            //  .lastBuildDate(date, timeZone: context.dateFormatter.timeZone),
            //  .pubDate(date, timeZone: context.dateFormatter.timeZone),
            //  .ttl(Int(config.ttlInterval)),
            //  .atomLink(context.site.url(for: config.targetPath)),
            .forEach(items, \.node)
        )
    }

}


extension RSSFeed {
    static func recentPackages(on database: Database,
                               maxItemCount: Int = Constants.rssFeedMaxItemCount) -> EventLoopFuture<Self> {
        RecentPackage.fetch(on: database, limit: maxItemCount)
            .mapEach(RSSFeed.Item.init)
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
            .mapEach(RSSFeed.Item.init)
            .map {
                RSSFeed(title: "Swift Package Index – Recent Releases",
                        description: "List of recently Swift packages releases",
                        link: SiteURL.rssPackages.absoluteURL(),
                    items: $0)
        }
    }
}


extension RSSFeed.Item {
    init(_ recentPackage: RecentPackage) {
        let title = recentPackage.packageName
        let link = SiteURL.package(.value(recentPackage.repositoryOwner),
                                   .value(recentPackage.repositoryName)).absoluteURL()
        let packageName = recentPackage.packageName
        let packageSummary = recentPackage.packageSummary ?? ""
        node = .item(
            .guid(.text(link), .isPermaLink(true)),
            .title(title),
            .link(link),
            .content(
                .h2(.a(.href(link), .text(packageName))),
                .p(.text(packageSummary)),
                .element(named: "small", nodes: [.a(.href(link), .text(packageName))])
            )
        )
    }

    init(_ recentRelease: RecentRelease) {
        let title = recentRelease.packageName
        let link = SiteURL.package(.value(recentRelease.repositoryOwner),
                                   .value(recentRelease.repositoryName)).absoluteURL()
        let packageName = recentRelease.packageName
        let version = recentRelease.version
        let packageSummary = recentRelease.packageSummary ?? ""
        node = .item(
            .guid(.text(link), .isPermaLink(true)),
            .title(title),
            .link(link),
            .content(
                .h2(.a(.href(link), .text("\(packageName) – \(version)"))),
                .p(.text(packageSummary)),
                .element(named: "small", nodes: [.a(.href(link), .text(packageName))])
            )
        )
    }
}
