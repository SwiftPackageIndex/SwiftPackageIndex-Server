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

enum Title {
    case bodyContext(Node<HTML.BodyContext>)
}

struct Breadcrumb {
    var title: String
    var url: String? = nil
    var choices: [Choice]? = nil


    struct Choice {
        var title: String
        var url: String
        var listItemClass: String?
    }

    init(title: String, url: String? = nil, choices: [Choice]? = nil) {
        self.title = title
        self.url = url
        self.choices = choices
    }

    func listNode() -> Node<HTML.ListContext> {
//        let x: Node<HTML.BodyContext> =

        return .li(
            .unwrap(choices, { choices in
                    .group(
                        .div(
                            .class("choices"),
                            .span(
                                .class("hello"),
                                .text("hello"),
                                .span(
                                    .class("hello"),
                                    .text("hello")
                                ),
                                .text("hello")
                            ),
                            .ul(
                                .group(
                                    choices.map { choice in
                                            .li(
                                                .unwrap(choice.listItemClass, { liClass in
                                                        .class(liClass)
                                                }),
                                                .a(
                                                    .href(choice.url),
                                                    .text(title)
                                                )
                                            )
                                    }
                                )
                            )
                        )
                    )
            }, else: .unwrap(url, {
                .a(
                    .href($0),
                    .span(
                        .class("hello"),
                        .text("hello"),
                        .span(
                            .class("hello"),
                            .text("hello")
                        ),
                        .text("hello")
                    )
                )
            }, else: .span(
                .class("hello"),
                .text("hello"),
                .span(
                    .class("hello"),
                    .text("hello")
                ),
                .text("hello")
            )))
        )
    }
}
