import Foundation

import Fluent
import Plot


extension HomeIndex {
    struct Model {
        var stats: Stats?
        var recentPackages: [DatedLink]
        var recentReleases: [Release]

        struct Release: Equatable {
            var packageName: String
            var version: String
            var date: String
            var url: String
        }
    }
}


extension HomeIndex.Model {
    static var numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.thousandSeparator = ","
        f.numberStyle = .decimal
        return f
    }()

    func statsClause() -> Node<HTML.BodyContext>? {
        guard
            let stats = stats,
            let packageCount = Self.numberFormatter.string(from: NSNumber(value: stats.packageCount)),
            let versionCount = Self.numberFormatter.string(from: NSNumber(value: stats.versionCount))
            else { return nil }
        return .element(named: "small",
                        text: "Indexing \(packageCount) packages and \(versionCount) versions.")
    }

    func recentPackagesSection() -> Node<HTML.ListContext> {
        .group(
            recentPackages.map { datedLink -> Node<HTML.ListContext> in
                .li(
                    .a(
                        .href(datedLink.link.url),
                        .text(datedLink.link.label)
                    ),
                    .element(named: "small", text: "Added \(datedLink.date)") // TODO: Fix after Plot update
                )
            }
        )
    }

    func recentReleasesSection() -> Node<HTML.ListContext> {
        .group(
            recentReleases.map { release -> Node<HTML.ListContext> in
                .li(
                    .a(
                        .href(release.url),
                        .text("\(release.packageName) "),
                        .element(named: "small", text: release.version)
                    ),
                    .element(named: "small", text: "Released \(release.date)") // TODO: Fix after Plot update
                )
            }
        )
    }
}
