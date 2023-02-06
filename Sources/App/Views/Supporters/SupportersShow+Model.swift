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

enum SupportersShow {
    struct Model {
        func preamble() -> Node<HTML.BodyContext> {
            .section(
                .class("preamble"),
                .div(
                    .p(
                        .text("This project is funded entirely by the generous financial support of the Swift community. Thank you to "),
                        .strong("everyone"),
                        .text(" who supports this project. We couldn’t keep it running without you!")
                    ),
                    .p(
                        .text("Please consider adding your support through "),
                        .a(
                            .href(ExternalURL.projectSponsorship),
                            "our GitHub Sponsors page"
                        ),
                        .text(". Or, if you are interested in corporate sponsorship, please "),
                        .a(
                            .href("mailto:contact@swiftpackageindex.com"),
                            "get in touch"
                        ),
                        .text(".")
                    )
                ),
                .div(
                    .div(
                        .class("ghcta"),
                        .a(
                            .href(ExternalURL.projectSponsorship),
                            .text("Please consider supporting the Swift Package Index through GitHub Sponsors.")
                        )
                    )
                )
            )
        }

        func corporateSupporters() -> Node<HTML.BodyContext> {
            .section(
                .class("corporate"),
                .h3("Corporate Supporters"),
                .ul(
                    .group(
                        Supporters.corporate.shuffled().map(\.listNode)
                    )
                )
            )
        }

        func infrastructureSupporters() -> Node<HTML.BodyContext> {
            .section(
                .class("infrastructure"),
                .h3("Infrastructure Supporters"),
                .ul(
                    .group(
                        Supporters.infrastructure.shuffled().map(\.listNode)
                    )
                )
            )
        }

        func communitySupporters() -> Node<HTML.BodyContext> {
            .section(
                .class("community"),
                .h3("Community Supporters"),
                .ul(
                    .group(
                        Supporters.community.shuffled().map(\.listNode)
                    )
                )
            )
        }
    }
}

extension Supporters.Corporate {
    var listNode: Node<HTML.ListContext> {
        .li(
            .a(
                .href(url),
                .picture(
                    .source(
                        .srcset(logo.darkModeUrl),
                        .media("(prefers-color-scheme: dark)")
                    ),
                    .img(
                        .alt("\(name) logo"),
                        .src(logo.lightModeUrl),
                        .width(300),
                        .height(75)
                    )
                )
            )
        )
    }
}

extension Supporters.Community {
    var listNode: Node<HTML.ListContext> {
        .li(
            .a(
                .href(gitHubUrl),
                .img(
                    .src(avatarUrl),
                    .alt("Profile picture for \(name ?? login)"),
                    .width(50),
                    .height(50),
                    .attribute(named: "loading", value: "lazy")
                ),
                .div(
                    .unwrap(name, { .div(.text($0)) }),
                    .div(.text(login))
                )
            )
        )
    }
}
