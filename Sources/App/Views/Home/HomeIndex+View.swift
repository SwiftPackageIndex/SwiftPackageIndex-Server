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
                    homePageCTA(),
                    recentPackageLists()
                ),
                .section(
                    supporterSidebar()
                )
            )
        }

        func homePageCTA() -> Node<HTML.BodyContext> {
            .section(
                .panelButton(cssClass: "podcast",
                             linkUrl: ExternalURL.podcast,
                             bodyNode: .podcastPanelBody(includeHeading: false),
                             cta: "Listen Now",
                             analyticsEvent: "Home - Podcast CTA")
            )
        }

        func recentPackageLists() -> Node<HTML.BodyContext> {
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
        }

        func supporterSidebar() -> Node<HTML.BodyContext> {
            .section(
                .class("supporter-ctas"),
                .panelButton(cssClass: "scta",
                             linkUrl: SiteURL.supporters.relativeURL(),
                             bodyNode: .sponsorsCtaBody(),
                             analyticsEvent: "Home - Supporters CTA"),
                .group(
                    Supporters.corporate.shuffled().map(\.advertisementNode)
                ),
                .if(Supporters.corporate.count < 2, .div(
                    .class("ccta-availability"),
                    .p(
                        .class("support"),
                        .text("Support the Swift Package Index")
                    ),
                    .p(
                        .text("We have one homepage sponsorship spot available. Support the project while promoting your company.")
                        ),
                    .p(
                        .class("cta"),
                        .a(
                            .href(ExternalURL.contactMailto),
                            .text("Get in touch for details →")
                        )
                    )
                ))
            )
        }

        override func navMenuItems() -> [NavMenuItem] {
            [.supporters, .addPackage, .blog, .faq]
        }
    }
}

extension Supporters.Corporate {
    var advertisementNode: Node<HTML.BodyContext> {
        .panelButton(cssClass: "ccta",
                     linkUrl: url,
                     bodyNode: advertisingBodyNode,
                     cta: "Visit \(name)",
                     analyticsEvent: "Home - Sponsor CTA (\(name))")
    }

    var advertisingBodyNode: Node<HTML.AnchorContext> {
        .group(
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
            .unwrap(advertisingCopy, { .text($0) })
        )
    }
}
