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
}
