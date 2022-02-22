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

import Foundation
import Plot

extension Node where Context: HTML.BodyContext {
    static func turboFrame(id: String, source: String? = nil, _ nodes: Node<HTML.BodyContext>...) -> Self {
        let attributes: [Node<HTML.BodyContext>] = [
            .attribute(named: "id", value: id),
            .attribute(named: "src", value: source)
        ]
        return .element(named: "turbo-frame", nodes: attributes + nodes)
    }

    static func structuredData<T>(_ model: T) -> Node<HTML.BodyContext> where T: Encodable {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [ .sortedKeys, .withoutEscapingSlashes ]

        do {
            let data = try encoder.encode(model)
            let rawScript = String(decoding: data, as: UTF8.self)

            return .script(
                .attribute(named: "type", value: "application/ld+json"),
                .raw(rawScript)
            )
        } catch {
            AppEnvironment.logger?.error("Failed to encode structured data model: \(error)")
            return .empty
        }
    }

    static func spiReadme(_ nodes: Node<HTML.BodyContext>...) -> Self {
        .element(named: "spi-readme", nodes: nodes)
    }
    
    static func spiTabBar(_ nodes: Node<HTML.BodyContext>...) -> Self {
        .element(named: "tab-bar", nodes: nodes)
    }

    static func spiOverflowingList(_ nodes: Node<HTML.ListContext>...) -> Self {
        .element(named: "spi-overflowing-list", nodes:[ .ul(.group(nodes)) ])
    }

    static func spinner() -> Self {
        .div(
            .class("spinner"),
            .div(.class("rect1")),
            .div(.class("rect2")),
            .div(.class("rect3")),
            .div(.class("rect4")),
            .div(.class("rect5"))
        )
    }

    static func searchForm(query: String = "", autofocus: Bool = true) -> Self {
        .form(
            .action(SiteURL.search.relativeURL()),
            .searchField(query: query, autofocus: autofocus),
            .button(
                .type(.submit),
                .div(
                    .title("Search")
                )
            )
        )
    }

    static func copyableInputForm(buttonName: String, eventName: String, valueToCopy: String) -> Self {
        .form(
            .class("copyable_input"),
            .input(
                .type(.text),
                .data(named: "button-name", value: buttonName),
                .data(named: "event-name", value: eventName),
                .value(valueToCopy),
                .readonly(true)
            )
        )
    }
}

extension Node where Context == HTML.FormContext {
    static func searchField(query: String = "", autofocus: Bool = true) -> Self {
        .input(
            .id("query"),
            .name("query"),
            .type(.search),
            .placeholder("Search"),
            .spellcheck(false),
            .autocomplete(false),
            .enableGrammarly(false),
            .data(named: "focus", value: String(autofocus)),
            .value(query)
        )
    }
}

extension Node where Context == HTML.ListContext {
    static func starsListItem(numberOfStars: Int) -> Self {
        if let formattedStars = NumberFormatter.spiDefault.string(from: numberOfStars) {
            return .li(
                .class("stars"),
                .small(
                    .text(formattedStars),
                    .text(" stars")
                )
            )
        } else {
            return .empty
        }
    }

    static func packageListItem(linkUrl: String, packageName: String, summary: String?, repositoryOwner: String, repositoryName: String, stars: Int?, lastActivityAt: Date?) -> Self {
        .li(
            .a(
                .href(linkUrl),
                .h4(.text(packageName)),
                .unwrap(summary) { .p(.text($0)) },
                .ul(
                    .class("metadata"),
                    .li(
                        .class("identifier"),
                        .small(
                            .text("\(repositoryOwner)/\(repositoryName)")
                        )
                    ),
                    .unwrap(lastActivityAt) {
                        .li(
                            .class("activity"),
                            .small(
                                .text("Active \(date: $0, relativeTo: Current.date())")
                            )
                        )
                    },
                    .unwrap(stars) {
                        .starsListItem(numberOfStars: $0)
                    }
                )
            )
        )
    }
}

// Custom attributes specific to the Swift Package Index

extension Attribute where Context == HTML.InputContext {
    static func enableGrammarly(_ isEnabled: Bool) -> Attribute {
        .data(named: "gramm", value: String(isEnabled))
    }
}
