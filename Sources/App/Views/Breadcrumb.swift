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

struct Breadcrumb {
    var title: Title
    var url: String? = nil
    var choices: [Node<HTML.ListContext>]? = nil

    struct Title {
        var content: [Node<HTML.BodyContext>]

        init(_ content: Node<HTML.BodyContext>...) {
            self.content = content
        }
    }

    init(title: Title, url: String? = nil, choices: [Node<HTML.ListContext>]? = nil) {
        self.title = title
        self.url = url
        self.choices = choices
    }

    init(title: String, url: String? = nil, choices: [Node<HTML.ListContext>]? = nil) {
        self.title = Title(.text(title))
        self.url = url
        self.choices = choices
    }

    func listNode() -> Node<HTML.ListContext> {
        .li(
            .unwrap(choices, { choices in
                    .group(
                        .div(
                            .class("choices"),
                            title.render(),
                            .ul(
                                .group(choices)
                            )
                        )
                    )
            }, else: .unwrap(url, {
                .a(
                    .href($0),
                    title.render()
                )
            }, else: title.render()))
        )
    }
}

extension Breadcrumb.Title {
    func render() -> Node<HTML.AnchorContext> {
        return .element(named: "span", nodes: content)
    }

    func render() -> Node<HTML.BodyContext> {
        return .element(named: "span", nodes: content)
    }
}
