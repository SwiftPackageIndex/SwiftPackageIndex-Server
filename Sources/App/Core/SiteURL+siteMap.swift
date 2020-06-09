import Fluent
import Plot


extension SiteURL {

    static var staticRoutes: [SiteURL] = [
        .faq, .home, .privacy
    ]

    static func siteMap(with packages: [(owner: String, repository: String)]) -> SiteMap {
        .init(
            .forEach(staticRoutes) {
                .url(
                    .loc($0.absoluteURL()),
                    .changefreq($0.changefreq)
                )
            },
            .forEach(packages) { owner, repo in
                .url(
                    .loc(SiteURL.package(.value(owner), .value(repo)).absoluteURL()),
                    .changefreq(SiteURL.package(.value(owner), .value(repo)).changefreq)
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
