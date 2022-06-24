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

import Foundation

import Fluent
import Plot


extension HomeIndex {
    struct Model {
        var stats: Stats?
        var recentPackages: [DatedLink]
        var recentReleases: [Release]

        static var currentSponsors = [
            SponsoredLink(sponsorName: "Stream", logoSource: "/images/sponsors/stream.svg", darkLogoSource: "/images/sponsors/stream~dark.svg", body: "Build real-time chat messaging in less time. Rapidly ship highly reliable chat in-app messaging with Stream's SDK.", cta: "Get Started", url: "https://getstream.io/chat/sdk/swiftui/?utm_source=SwiftPackageIndex&utm_medium=Github_Repo_Content_Ad&utm_content=Developer&utm_campaign=SwiftPackageIndex_Apr2022_SwiftUIChat"),
            SponsoredLink(sponsorName: "Runway", logoSource: "/images/sponsors/runway.svg", darkLogoSource: "/images/sponsors/runway~dark.svg", body: "Release faster and more reliably with Runway. Runway integrates with all of your tools, enabling end-to-end automation and seamless coordination across your team.", cta: "Try Runway for free", url: "https://www.runway.team/?utm_source=sponsorship&utm_medium=website&utm_campaign=swiftpackageindex&utm_content=may_2022")
        ]

        static var twitterSpaceLinks = TwitterSpaceLinks(
            previousUrl: "https://blog.swiftpackageindex.com/posts/swift-package-indexing-episode-5/",
            nextUrl: "https://twitter.com/i/spaces/1PlKQaNYkAVKE"
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
            let cta: String
            let url: String
        }

        struct TwitterSpaceLinks {
            let previousUrl: String
            let nextUrl: String
        }

        func sponsoredLink() -> SponsoredLink? {
            Self.currentSponsors.randomElement()
        }
    }
}


extension HomeIndex.Model {
    static var numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.thousandSeparator = ","
        f.numberStyle = .decimal
        return f
    }()
    
    func statsDescription() -> String? {
        guard
            let stats = stats,
            let packageCount = Self.numberFormatter.string(from: NSNumber(value: stats.packageCount))
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
