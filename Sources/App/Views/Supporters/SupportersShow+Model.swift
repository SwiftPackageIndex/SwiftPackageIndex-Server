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

        func corporateSupporters() -> Node<HTML.BodyContext> {
            .empty
        }

        func communitySupporters() -> Node<HTML.BodyContext> {
            .section(
                .class("community-supporters"),
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
