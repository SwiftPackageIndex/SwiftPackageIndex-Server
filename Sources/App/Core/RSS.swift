import Foundation
import Plot


struct RSSFeed {
    struct Item {
        var title: String
        var link: String
        var content: String

        var node: Node<RSS.ChannelContext> {
            .item(
                .guid(.text(link), .isPermaLink(true)),
                .title(title),
                .link(link)
            )
        }
    }

    var title: String
    var description: String
    var link: URL
    var maxItemCount: Int
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
            .forEach(items.prefix(maxItemCount), \.node)
        )

    }
}
