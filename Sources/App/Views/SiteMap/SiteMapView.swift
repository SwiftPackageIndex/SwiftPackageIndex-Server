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

import Foundation
import Plot

enum SiteMapView {

    static func packageSiteMap(owner: String?,
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
}
