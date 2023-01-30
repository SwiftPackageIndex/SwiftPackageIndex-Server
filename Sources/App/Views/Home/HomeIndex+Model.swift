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

import Fluent
import Plot


extension HomeIndex {
    struct Model {
        var stats: Stats?
        var recentPackages: [DatedLink]
        var recentReleases: [Release]

        static var currentSponsors = [
            SponsoredLink(sponsorName: "Stream", logoSource: "/images/sponsors/stream.svg", darkLogoSource: "/images/sponsors/stream~dark.svg", body: "Build reliable, real-time, in-app chat and messaging in less time.", url: "https://getstream.io/chat/sdk/swiftui/?utm_source=SwiftPackageIndex&utm_medium=Github_Repo_Content_Ad&utm_content=Developer&utm_campaign=SwiftPackageIndex_Apr2022_SwiftUIChat"),
            SponsoredLink(sponsorName: "Emerge Tools", logoSource: "/images/sponsors/emerge.png", darkLogoSource: "/images/sponsors/emerge~dark.png", body: "Monitor app size, improve startup time, and prevent performance regressions.", url: "https://www.emergetools.com/?utm_source=spi&utm_medium=sponsor&utm_campaign=emerge")
        ]

        static var twitterSpaceLinks = TwitterSpaceLinks(
            previousUrl: "https://blog.swiftpackageindex.com/posts/swift-package-indexing-episode-13/",
            nextUrl: "https://twitter.com/i/spaces/1rmGPklbanXKN"
        )

        struct Release: Equatable {
            var packageName: String
            var version: String
            var date: String
            var url: String
        }

        struct SponsoredLink {
            let sponsorName: String
            let logoSource: String
            let darkLogoSource: String
            let body: String
            let url: String
        }

        struct TwitterSpaceLinks {
            let previousUrl: String
            let nextUrl: String
        }
    }
}


extension HomeIndex.Model {
    func statsDescription() -> String? {
        guard
            let stats = stats,
            let packageCount = NumberFormatter.spiDefault.string(from: NSNumber(value: stats.packageCount))
        else { return nil }
        return "\(packageCount) packages"
    }

    func statsClause() -> Node<HTML.BodyContext>? {
        guard let description = statsDescription() else { return nil }
        return .small(
            .text("Indexing "),
            .text(description)
        )
    }

    func recentPackagesSection() -> Node<HTML.ListContext> {
        .group(
            recentPackages.map { datedLink -> Node<HTML.ListContext> in
                .li(
                    .a(
                        .href(datedLink.link.url),
                        .text(datedLink.link.label)
                    ),
                    .small(.text("Added \(datedLink.date)"))
                )
            }
        )
    }

    func recentReleasesSection() -> Node<HTML.ListContext> {
        .group(
            recentReleases.map { release -> Node<HTML.ListContext> in
                .li(
                    .a(
                        .href(release.url),
                        .text("\(release.packageName) "),
                        .small(.text(release.version))
                    ),
                    .small(.text("Released \(release.date)"))
                )
            }
        )
    }
}
