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
        return try await buildIndex(db: req.db).encodeResponse(for: req)
    }

    static func buildIndex(db: Database) async throws -> SiteMapIndex {
        guard let db = db as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }

        // Drive sitemap from the search view as it only includes presentable packages.
        let query = db.select()
            .column(Search.repoOwner, as: "owner")
            .column(Search.repoName, as: "repository")
            .column(Search.lastActivityAt)
            .from(Search.searchView)
            .orderBy(Search.repoOwner)
            .orderBy(Search.repoName)

        let packages = try await query.all(decoding: Package.self)
        return SiteMapIndex(
            .sitemap(
                .loc(SiteURL.siteMapStaticPages.absoluteURL()),
                .lastmod(Current.date()) // The home page updates every day.
            ),
            .group(
                packages.map { package -> Node<SiteMapIndex.SiteMapIndexContext> in
                        .sitemap(
                            .loc(SiteURL.package(.value(package.owner),
                                                 .value(package.repository),
                                                 .siteMap).absoluteURL()),
                            .unwrap(package.lastActivityAt, { .lastmod($0) })
                        )
                }
            )
        )
    }

    static func staticPages(req: Request) async throws -> Response {
        try await buildStaticPages().encodeResponse(for: req)
    }

    static func buildStaticPages() -> SiteMap {
        SiteMap(.group(
            staticRoutes.map { page -> Node<SiteMap.URLSetContext> in
                    .url(
                        .loc(page.absoluteURL())
                    )
            }
        ))
    }

    static func mapForPackage(req: Request) async throws -> Response {
        guard
            let owner = req.parameters.get("owner"),
            let repository = req.parameters.get("repository")
        else { throw Abort(.notFound) }

        return try await buildMapForPackage(db: req.db, owner: owner, repository: repository).encodeResponse(for: req)
    }

    static func buildMapForPackage(db: Database, owner: String, repository: String) async throws -> SiteMap {
        let packageResult = try await PackageController.PackageResult.query(on: db, owner: owner, repository: repository)

        return SiteMap(
            .url(
                .loc(SiteURL.package(.value(owner), .value(repository), .none).absoluteURL()),
                .unwrap(packageResult.repository.lastActivityAt, { .lastmod($0) })
            )
        )
    }
}
