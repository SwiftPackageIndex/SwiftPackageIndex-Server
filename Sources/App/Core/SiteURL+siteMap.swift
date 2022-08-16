// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Fluent
import Plot
import SQLKit


extension SiteURL {
    
    static var staticRoutes: [SiteRoute] = [.faq, .home, .privacy]

    static func siteMap(with packages: [SiteMap.Package]) -> SiteMap {
        .init(
            .forEach(staticRoutes) {
                .url(
                    .loc(SiteRoute.absoluteURL(for: $0)),
                    .changefreq($0.changefreq)
                )
            },
            .forEach(packages) { p in
                .url(
                    .loc(
                        SiteRoute.absoluteURL(for: .package(owner: p.owner, repository: p.repository))
                    ),
                    .changefreq(
                        SiteRoute.package(owner: p.owner, repository: p.repository).changefreq
                    )
                )
            }
        )
    }
    
    @available(*, deprecated)
    var changefreq: SiteMapChangeFrequency {
        switch self {
            case .api:
                return .weekly
            case .author:
                return .daily
            case .buildMonitor:
                return .hourly
            case .builds:
                return .daily
            case .images:
                return .weekly
            case .javascripts:
                return .weekly
            case .keywords:
                return .daily
            case .package:
                return .daily
            case .packageCollection:
                return .daily
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
        }
    }
    
}


private extension SiteRoute {
    var changefreq: SiteMapChangeFrequency {
        switch self {
            case .api:
                return .weekly
            case .addAPackage:
                return .weekly
            case .docs:
                return .weekly
            case .faq:
                return .weekly
            case .home:
                return .hourly
            case .keywords:
                return .daily
            case .package:
                return .daily
            case .packageCollections:
                return .daily
            case .privacy:
                return .monthly
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
