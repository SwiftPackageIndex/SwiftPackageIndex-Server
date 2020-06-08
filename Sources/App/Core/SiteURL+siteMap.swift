import Plot


extension SiteURL {

    /// Routes that are exposed in the sitemap
    static var siteMapRoutes: [SiteURL] = [
        .faq, .home, .privacy
    ]

    static func siteMap() -> SiteMap {
        .init(
            .forEach(siteMapRoutes) {
                .url(
                    .loc($0.absoluteURL()),
                    .changefreq($0.changefreq)
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
