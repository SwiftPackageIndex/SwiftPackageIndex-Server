// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
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

import Vapor
import SQLKit
import Plot

enum SiteMapController {

    struct Package: Equatable, Decodable {
        var owner: String
        var repository: String
        var lastActivityAt: Date

        enum CodingKeys: String, CodingKey {
            case owner
            case repository
            case lastActivityAt = "last_activity_at"
        }
    }

    static var staticRoutes: [SiteURL] = [
        .home,
        .addAPackage,
        .faq,
        .supporters,
        .buildMonitor,
        .privacy
    ]

    static func index(req: Request) async throws -> Response {
        guard let db = req.db as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }

        // Drive sitemap from the search view as it only includes presentable packages.
        let query = db.select()
            .column(Search.repoOwner, as: "owner")
            .column(Search.repoName, as: "repository")
            .column(Search.lastActivityAt, as: "last_activity_at")
            .from(Search.searchView)
            .orderBy(Search.repoOwner)
            .orderBy(Search.repoName)

        let packages = try await query.all(decoding: Package.self)
        return SiteMapIndex(.group(
            packages.map { package -> Node<SiteMapIndex.SiteMapIndexContext> in
                return .sitemap(
                    .loc(SiteURL.package(.value(package.owner),
                                         .value(package.repository),
                                         .siteMap).absoluteURL()),
                    .lastmod(package.lastActivityAt)
                )
            }
        )).encodeResponse(for: req)
    }

    static func staticPagesSiteMap(req: Request) async throws -> Response {
        return SiteMap(.group(
            staticRoutes.map { page -> Node<SiteMap.URLSetContext> in
                    .url(
                        .loc(page.absoluteURL()),
                        .changefreq(page.changefreq)
                    )
            }
        )).encodeResponse(for: req)
    }

//    static func sitemap(req: Request) async throws -> Response {
//        guard
//            let owner = req.parameters.get("owner"),
//            let repository = req.parameters.get("repository")
//        else {
//            throw Abort(.notFound)
//        }
//    }

    //    static func siteMap(with packages: [SiteMap.Package]) -> SiteMap {
    //        .init(
    //            .forEach(staticRoutes) {
    //                .url(
    //                    .loc($0.absoluteURL()),
    //                    .changefreq($0.changefreq)
    //                )
    //            },
    //            .forEach(packages) { package in
    //                    .group(
    //                        .url(
    //                            .loc(SiteURL.package(.value(package.owner),
    //                                                 .value(package.repository),
    //                                                 .none).absoluteURL()),
    //                            .changefreq(SiteURL.package(.value(package.owner),
    //                                                        .value(package.repository),
    //                                                        .none).changefreq)
    //                        ),
    //                        .unwrap(package.hasDocs, { hasDocs in
    //                                .if(hasDocs, .url(
    //                                    .loc(SiteURL.package(.value(package.owner),
    //                                                         .value(package.repository),
    //                                                         .documentation).absoluteURL()),
    //                                    .changefreq(SiteURL.package(.value(package.owner),
    //                                                                .value(package.repository),
    //                                                                .documentation).changefreq)
    //                                ))
    //                        })
    //                    )
    //            }
    //        )
    //    }

}

extension SiteURL {
    var changefreq: SiteMapChangeFrequency {
        switch self {
            case .addAPackage:
                return .weekly
            case .api:
                return .weekly
            case .author:
                return .daily
            case .buildMonitor:
                return .hourly
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
            case .validateSPIManifest:
                return .monthly
            case .siteMapIndex:
                return .weekly
            case .supporters:
                return .weekly
            case .stylesheets:
                return .weekly
            case .tryInPlayground:
                return .monthly
        }
    }
}
