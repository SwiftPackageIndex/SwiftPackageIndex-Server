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
import Fluent
import SQLKit
import Plot

enum SiteMapController {

    struct Package: Equatable, Decodable {
        var owner: String
        var repository: String
        var lastActivityAt: Date?

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

        // Only serve sitemaps in production.
        guard Current.environment() == .production
        else { throw Abort(.notFound) }

        // Drive sitemap from the search view as it only includes presentable packages.
        let query = db.select()
            .column(Search.repoOwner, as: "owner")
            .column(Search.repoName, as: "repository")
            .column(Search.lastActivityAt)
            .from(Search.searchView)
            .orderBy(Search.repoOwner)
            .orderBy(Search.repoName)

        let packages = try await query.all(decoding: Package.self)
        return try await SiteMapIndex(
            .sitemap(
                .loc(SiteURL.siteMapStaticPages.absoluteURL()),
                .lastmod(Current.date(), timeZone: .utc) // The home page updates every day.
            ),
            .group(
                packages.map { package -> Node<SiteMapIndex.SiteMapIndexContext> in
                        .sitemap(
                            .loc(SiteURL.package(.value(package.owner),
                                                 .value(package.repository),
                                                 .siteMap).absoluteURL()),
                            .unwrap(package.lastActivityAt, { .lastmod($0, timeZone: .utc) })
                        )
                }
            )
        ).encodeResponse(for: req)
    }

    static func staticPages(req: Request) async throws -> Response {
        // Only serve sitemaps in production.
        guard Current.environment() == .production
        else { throw Abort(.notFound) }

        return try await SiteMap(.group(
            staticRoutes.map { page -> Node<SiteMap.URLSetContext> in
                    .url(
                        .loc(page.absoluteURL())
                    )
            }
        )).encodeResponse(for: req)
    }
}
