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
                    .loc(
                        SiteURL.package(.value(p.owner), .value(p.repository), .none).absoluteURL()),
                    .changefreq(
                        SiteURL.package(.value(p.owner), .value(p.repository), .none).changefreq)
                )
            }
        )
    }
    
    var changefreq: SiteMapChangeFrequency {
        switch self {
            case .addAPackage:
                return .weekly
            case .api:
                return .weekly
            case .author:
                return .daily
            case .builds:
                return .daily
            case .docs:
                return .weekly
            case .faq:
                return .weekly
            case .home:
                return .hourly
            case .images:
                return .weekly
            case .javascripts:
                return .weekly
            case .keywords:
                return .daily
            case .package:
                return .daily
            case .packageCollections:
                return .daily
            case .packageCollection:
                return .daily
            case .privacy:
                return .monthly
            case .rssPackages:
                return .hourly
            case .rssReleases:
                return .hourly
            case .search:
                return .hourly
            case .siteMap:
                return .weekly
            case .stylesheets:
                return .weekly
            case .tryInPlayground:
                return .monthly
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
        
        // Drive sitemap from the search view for two reasons:
        // 1) access is fast
        // 2) packages listed are valid for presentation
        let query = db.select()
            .column(Search.repoName, as: "name")
            .column(Search.repoOwner, as: "owner")
            .from(Search.searchView)
            .orderBy(Search.repoName)
            .orderBy(Search.repoOwner)
        
        return query.all(decoding: Package.self)
    }
}
