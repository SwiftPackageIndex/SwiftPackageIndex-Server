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
                        .class("podcast"),
                        .p(
                            .text("Join Dave and Sven biweekly for a chat about ongoing Swift Package Index development and a selection of package recommendations on our "),
                            .a(
                                .href("https://swiftpackageindexing.transistor.fm"),
                                "Swift Package Indexing podcast"
                            ),
                            .text(".")
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
                                "joining \(Supporters.community.count) other sponsors"
                            ),
                            .text(".")
                        ),
                        .p(
                            .div(
                                .class("avatars"),
                                .forEach(Supporters.community.randomSample(count: numberOfCommunitySponsors), { sponsor in
                                        .a(
                                            .href(ExternalURL.projectSponsorship),
                                            .img(
                                                .src(sponsor.avatarUrl),
                                                .unwrap(sponsor.name, { .title($0) }),
                                                .alt("Profile picture for \(sponsor.name ?? sponsor.login)"),
                                                .width(30),
                                                .height(30)
                                            )
                                        )
                                })
                            ),
                            .small(
                                .a(
                                    .href(ExternalURL.projectSponsorship),
                                    .text("&hellip; and \(Supporters.community.count - numberOfCommunitySponsors) more.")
                                )
                            )
                        )
                    ),
                    .group(
                        Supporters.corporate.shuffled().map(\.advertisementNode)
                    ),
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
            [.supporters, .addPackage, .blog, .faq]
        }
    }
}

extension Supporters.Corporate {
    var advertisementNode: Node<HTML.BodyContext> {
        .a(
            .href(url),
            .div(
                .class("ccta"),
                .picture(
                    .source(
                        .srcset(logo.darkModeUrl),
                        .media("(prefers-color-scheme: dark)")
                    ),
                    .img(
                        .alt("\(name) logo"),
                        .src(logo.lightModeUrl)
                    )
                ),
                .unwrap(advertisingCopy, { .p(.text($0)) })
            )
        )
    }
}
