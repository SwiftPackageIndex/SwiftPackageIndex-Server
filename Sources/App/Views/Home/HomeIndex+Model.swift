import Fluent
import Plot


extension HomeIndex {
    struct Model {
        var recentPackages: [DatedLink]
        var recentReleases: [DatedLink]
    }
}


extension HomeIndex.Model {
    func recentPackagesSection() -> Node<HTML.ListContext> {
        .group(
            recentPackages.map { datedLink -> Node<HTML.ListContext> in
                .li(
                    .a(
                        .href(datedLink.link.url),
                        .text(datedLink.link.label)
                    ),
                    .element(named: "small", text: "Added \(datedLink.date).") // TODO: Fix after Plot update
                )
            }
        )
    }

    func recentReleasesSection() -> Node<HTML.ListContext> {
        .group(
            recentReleases.map { datedLink -> Node<HTML.ListContext> in
                .li(
                    .a(
                        .href(datedLink.link.url),
                        .text(datedLink.link.label)
                    ),
                    .element(named: "small", text: "Released \(datedLink.date).") // TODO: Fix after Plot update
                )
            }
        )
    }
}
