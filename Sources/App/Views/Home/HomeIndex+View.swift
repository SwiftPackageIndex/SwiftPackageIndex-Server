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

import Plot


enum HomeIndex {

    class View: PublicPage {

        let model: Model

        let numberOfCommunitySponsors = 14

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }

        override func pageDescription() -> String? {
            let description = "The Swift Package Index is the place to find the best Swift packages."

            guard let statsDescription = model.statsDescription()
            else { return description }

            return "\(description) Indexing metadata from \(statsDescription) packages."
        }

        override func bodyClass() -> String? {
            "home"
        }

        override func postBody() -> Node<HTML.BodyContext> {
            .structuredData(IndexSchema())
        }

        override func preMain() -> Node<HTML.BodyContext> {
            .section(
                .class("search home"),
                .div(
                    .class("inner"),
                    .h3("The place to find Swift packages."),
                    .searchForm(),
                    .unwrap(model.statsClause()) { $0 }
                )
            )
        }

        override func content() -> Node<HTML.BodyContext> {
            .section(
                .class("two-column"),
                .section(
                    .section(
                        .class("twitter-spaces"),
                        .p(
                            .text("Join us for our "),
                            .a(
                                .href(Model.twitterSpaceLinks.nextUrl),
                                "next Twitter Space"
                            ),
                            .text(" discussing new and updated packages. Or catch up with "),
                            .a(
                                .href(Model.twitterSpaceLinks.previousUrl),
                                "our most recent episode"
                            ),
                            .text(".")
                        ),
                        .p(
                            .class("twitter-profile"),
                            .small(
                                .text("Follow along at "),
                                .a(
                                    .href(ExternalURL.twitter),
                                    "@SwiftPackages"
                                )
                            )
                        )
                    ),
                    .section(
                        .class("recent"),
                        .div(
                            .class("recent_packages"),
                            .h3("Recently Added"),
                            .ul(model.recentPackagesSection())
                        ),
                        .div(
                            .class("recent_releases"),
                            .h3("Recent Releases"),
                            .ul(model.recentReleasesSection())
                        )
                    )
                ),
                .section(
                    .div(
                        .class("scta"),
                        .p(
                            .text("This project wouldn't be possible without "),
                            .a(
                                .href(ExternalURL.projectSponsorship),
                                .text("community support")
                            ),
                            .text(". Please consider "),
                            .a(
                                .href(ExternalURL.projectSponsorship),
                                "joining \(CommunitySponsors.sponsors.count) other sponsors"
                            ),
                            .text(".")
                        ),
                        .p(
                            .div(
                                .class("avatars"),
                                .forEach(CommunitySponsors.sponsors.randomSample(count: numberOfCommunitySponsors), { sponsor in
                                        .a(
                                            .href(ExternalURL.projectSponsorship),
                                            .img(
                                                .src(sponsor.avatarUrl),
                                                .unwrap(sponsor.name, { .title($0) }),
                                                .alt(sponsor.name ?? "Profile picture")
                                            )
                                        )
                                })
                            ),
                            .small(
                                .a(
                                    .href(ExternalURL.projectSponsorship),
                                    .text("&hellip; and \(CommunitySponsors.sponsors.count - numberOfCommunitySponsors) more.")
                                )
                            )
                        )
                    ),
                    .forEach(Model.currentSponsors.shuffled(), { sponsoredLink in
                            .group(
                                .a(
                                    .href(sponsoredLink.url),
                                    .div(
                                        .class("ccta"),
                                        .picture(
                                            .source(
                                                .srcset(sponsoredLink.darkLogoSource),
                                                .media("(prefers-color-scheme: dark)")
                                            ),
                                            .img(
                                                .alt("\(sponsoredLink.sponsorName) logo"),
                                                .src(sponsoredLink.logoSource)
                                            )
                                        ),
                                        .p(
                                            .text(sponsoredLink.body)
                                        )
                                    )
                                )
                            )
                    }),
                    .small(
                        .text("Thanks so much to all of our generous sponsors for "),
                        .a(
                            .href("https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/blob/main/README.md#funding-and-sponsorship"),
                            .text("supporting this project")
                        ),
                        .text(".")
                    )
                )
            )
        }

        override func navMenuItems() -> [NavMenuItem] {
            [.addPackage, .blog, .faq]
        }
    }
}
