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

enum NavMenuItem {
    case sponsorCTA
    case addPackage
    case blog
    case faq
    case search
    case searchLink

    func listNode() -> Node<HTML.ListContext> {
        switch self {
            case .sponsorCTA:
                return .li(
                    .class("menu_scta"),
                    .a(
                        .id("menu_scta"),
                        .href(ExternalURL.projectSponsorship)
                    ),
                    .div(
                        .id("menu_scta_help"),
                        .p("The Swift Package Index is an open-source project entirely funded by community donations."),
                        .p(
                            .text("Please consider sponsoring this project. "),
                            .strong("Thank you!")
                        )
                    )
                )
            case .addPackage:
                return .li(
                    .a(
                        .href(SiteURL.addAPackage.relativeURL()),
                        "Add a Package"
                    )
                )
            case .blog:
                return .li(
                    .a(
                        .href(ExternalURL.projectBlog),
                        "Blog"
                    )
                )
            case .faq:
                return .li(
                    .a(
                        .href(SiteURL.faq.relativeURL()),
                        "FAQ"
                    )
                )
            case .search:
                return .li(
                    .class("search"),
                    // The form inside the nav is shown only to desktop browsers through CSS.
                    .searchForm(autofocus: false),
                    // The link is shown only to mobile browsers only through CSS.
                    .a(
                        .href(SiteURL.search.relativeURL()),
                        .title("Search")
                    )
                )
            case .searchLink:
                return .li(
                    .a(
                        .href(SiteURL.search.relativeURL()),
                        .text("Package Search")
                    )
                )
        }
    }
}
