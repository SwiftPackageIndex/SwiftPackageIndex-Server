import Fluent
import Plot
import SQLKit


extension SiteURL {

    static var staticRoutes: [SiteURL] = [
        .faq, .home, .privacy
    ]

    static func siteMap(with packages: [SiteMap.Package]) -> SiteMap {
        .init(
            .forEach(staticRoutes) {
                .url(
                    .loc($0.absoluteURL()),
                    .changefreq($0.changefreq)
                )
            },
            .forEach(packages) { p in
                .url(
                    .loc(SiteURL.package(.value(p.owner), .value(p.repository)).absoluteURL()),
                    .changefreq(SiteURL.package(.value(p.owner), .value(p.repository)).changefreq)
                )
            }
        )
    }

    var changefreq: SiteMapChangeFrequency {
        switch self {
            case .admin:
                return .weekly
            case .api(_):
                return .weekly
            case .faq:
                return .weekly
            case .home:
                return .hourly
            case .images(_):
                return .weekly
            case .packages:
                return .daily
            case .package(_, _):
                return .daily
            case .privacy:
                return .monthly
            case .rssPackages:
                return .hourly
            case .rssReleases:
                return .hourly
            case .siteMap:
                return.weekly
        }
    }

}


extension SiteMap {
    struct Package: Equatable, Decodable {
        var owner: String
        var repository: String

        enum CodingKeys: String, CodingKey {
            case owner = "owner"
            case repository = "name"
        }
    }

    static func fetchPackages(_ database: Database) -> EventLoopFuture<[Package]> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }

        let query = db.select()
            .column(Search.repoName)
            .column(Search.repoOwner)
            .from(Search.searchView)
            .orderBy(Search.repoName)
            .orderBy(Search.repoOwner)

        return query.all(decoding: Package.self)
    }
}
