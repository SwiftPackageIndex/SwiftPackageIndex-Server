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
                .class("two_column"),
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
                ),
                .section(
                    .div(
                        .class("scta"),
                        .p(
                            .text("The Swift Package Index is an "),
                            .a(
                                .href(ExternalURL.projectGitHub),
                                "open-source"
                            ),
                            .text(" project funded by community donations.")
                        ),
                        .p(
                            .text("Please consider "),
                            .a(
                                .href(ExternalURL.projectSponsorship),
                                "sponsoring the project"
                            ),
                            .text(" to support the time we dedicate to it. "),
                            .strong("Thank you!")
                        )
                    ),
                    .unwrap(model.sponsoredLink(), { sponsoredLink in
                            .group(
                                .a(
                                    .href(sponsoredLink.url),
                                    .div(
                                        .class("ccta"),
                                        .unwrap(sponsoredLink.darkLogoSource, { darkLogoSource in
                                            .picture(
                                                .source(
                                                    .srcset(darkLogoSource),
                                                    .media("(prefers-color-scheme: dark)")
                                                ),
                                                .img(
                                                    .alt("\(sponsoredLink.sponsorName) logo"),
                                                    .src(sponsoredLink.logoSource)
                                                )
                                            )
                                        }, else:
                                            .img(
                                                .alt("\(sponsoredLink.sponsorName) logo"),
                                                .src(sponsoredLink.logoSource)
                                            )
                                        ),
                                        .p(
                                            .text(sponsoredLink.body),
                                            .text(" "),
                                            .span(
                                                .text(sponsoredLink.cta)
                                            ),
                                            .text(".")
                                        )
                                    )
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
                    })
                )
            )
        }

        override func navMenuItems() -> [NavMenuItem] {
            [.addPackage, .blog, .faq]
        }
    }
}

