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

    static let staticRoutes: [SiteURL] = [
        .home,
        .addAPackage,
        .faq,
        .supporters,
        .buildMonitor,
        .privacy
    ]

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

    /// Generate a sitemap index page for a given request
    /// - Parameter req: `Request`
    /// - Returns: `SiteMapIndex`
    static func index(req: Request) async throws -> SiteMapIndex {
        guard let db = req.db as? SQLDatabase else {
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
        return index(packages: packages)
    }

    /// Generate a sitemap index page for a given list of packages
    /// - Parameter packages: list of packages
    /// - Returns: `SiteMapIndex`
    static func index(packages: [SiteMapController.Package]) -> SiteMapIndex {
        SiteMapIndex(
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
        )
    }

    /// Generate a sitemap for a specific package
    /// - Parameters:
    ///   - owner: package owner (author)
    ///   - repository: repository name
    ///   - lastActivityAt: last activity
    ///   - linkablePathUrls: list of linkable path urls
    /// - Returns: `SiteMap`
    static func package(owner: String?,
                        repository: String?,
                        lastActivityAt: Date?,
                        linkablePathUrls: [String]) async throws -> SiteMap {
        guard let owner,
              let repository
        else {
            // This should never happen, but we should return an empty
            // sitemap instead of an incorrect one.
            return SiteMap()
        }

        // See SwiftPackageIndex-Server#2485 for context on the performance implications of this
        let lastmod: Node<SiteMap.URLContext> = lastActivityAt.map { .lastmod($0, timeZone: .utc) } ?? .empty

        return SiteMap(
            .url(
                .loc(SiteURL.package(.value(owner),
                                     .value(repository),
                                     .none).absoluteURL()),
                lastmod
            ),
            .forEach(linkablePathUrls, { url in
                    .url(.loc(url), lastmod)
            })
        )
    }

    static func staticPages(req: Request) async throws -> SiteMap {
        SiteMap(
            .group(
                staticRoutes.map { page -> Node<SiteMap.URLSetContext> in
                        .url(
                            .loc(page.absoluteURL())
                        )
                }
            )
        )
    }

}
