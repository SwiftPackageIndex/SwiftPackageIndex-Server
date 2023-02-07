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

enum NavMenuItem {
    case supporters
    case addPackage
    case blog
    case faq
    case search

    func listNode() -> Node<HTML.ListContext> {
        switch self {
            case .supporters:
                return .li(
                    .a(
                        .class("supporters"),
                        .href(SiteURL.supporters.relativeURL()),
                        "Supporters"
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
                    .searchForm(autofocus: false)
                )
        }
    }
}
