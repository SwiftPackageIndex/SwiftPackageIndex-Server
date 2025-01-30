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

import Foundation

import Dependencies
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
            @Dependency(\.logger) var logger
            logger.error("Failed to encode structured data model: \(error)")
            return .empty
        }
    }

    static func spiOverflowingList(overflowMessage: String,
                                   overflowHeight: Int,
                                   listClass: String? = nil,
                                   _ nodes: Node<HTML.ListContext>...) -> Self {
        // Note: The `overflowHeight` is a magic number that needs some experimentation each
        // time this tag is used. It's the exact size in pixels of the collapsed element. If
        // incorrect, the "show more" button will show up unnecessarily as it may overflow by
        // just a single invisible pixel.
        .div(
            .data(named: "controller", value: "overflowing-list"),
            .data(named: "overflowing-list-overflow-message-value", value: overflowMessage),
            .data(named: "overflowing-list-overflow-height-value", value: String(overflowHeight)),
            .data(named: "overflowing-list-collapsed-value", value: String(true)),
            .data(named: "action", value: "turbo:load@document->overflowing-list#addShowMoreLinkIfNeeded"),
            .ul(
                .data(named: "overflowing-list-target", value: "list"),
                .unwrap(listClass) { .class($0) },
                .group(nodes)
            )
        )
    }
    static func spiPanel(buttonText: String,
                         panelClass: String,
                         _ nodes: Node<HTML.BodyContext>...) -> Node<HTML.BodyContext> {
        .div(
            .data(named: "controller", value: "modal-panel"),
            .button(
                .data(named: "modal-panel-target", value: "button"),
                .data(named: "action", value: "click->modal-panel#show"),
                .text(buttonText)
            ),
            .section(
                .class(panelClass),
                .data(named: "modal-panel-target", value: "panel"),
                .button(
                    .class("close"),
                    .text("&times;"),
                    .data(named: "action", value: "click->modal-panel#hide")
                ),
                .group(nodes)
            )
        )
    }

    static func spiTabBar(tabs: [TabMetadata],
                          tabContent: [Node<HTML.BodyContext>]) -> Node<HTML.BodyContext> {
        .section(
            .data(named: "controller", value: "tab-bar"),
            .nav(
                .ul(
                    .class("tab-list"),
                    .forEach(tabs, { tab in
                            .li(
                                .id(tab.id),
                                .data(named: "tab-bar-target", value: "tab"),
                                .data(named: "action", value: "click->tab-bar#updateTab"),
                                .text(tab.title)
                            )
                    })
                )
            ),
            .forEach(tabContent, { tabNode in
                    .section(
                        .data(named: "tab-bar-target", value: "content"),
                        tabNode
                    )
            }),
            .noscript(.text("JavaScript must be enabled for the tab bar to be functional."))
        )
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

    static func copyableInputForm(buttonName: String,
                                  eventName: String,
                                  valueToCopy: String? = nil,
                                  inputNode: Attribute<HTML.InputContext>? = nil) -> Self {
        .form(
            .class("copyable-input"),
            .input(
                .type(.text),
                .unwrap(inputNode) { $0 },
                .data(named: "button-name", value: buttonName),
                .data(named: "event-name", value: eventName),
                .unwrap(valueToCopy) { .value($0) },
                .readonly(true)
            )
        )
    }

    static func panelButton(cssClass: String? = nil,
                            linkUrl: URLRepresentable,
                            body: String,
                            cta: String? = nil,
                            analyticsEvent: String? = nil) -> Self {
        .panelButton(cssClass: cssClass, linkUrl: linkUrl, bodyNode: .text(body), cta: cta, analyticsEvent: analyticsEvent)
    }

    static func panelButton(cssClass: String? = nil,
                            linkUrl: URLRepresentable,
                            bodyNode: Node<HTML.AnchorContext>,
                            cta: String? = nil,
                            analyticsEvent: String? = nil) -> Self {
        .div(
            .unwrap(analyticsEvent, { analyticsEvent in
                    .group(
                        .data(named: "controller", value: "panel-button"),
                        .data(named: "panel-button-analytics-event-value", value: analyticsEvent)
                    )
            }),
            .unwrap(cssClass, { .class("panel-button \($0)") },
                    else: .class("panel-button")),
            .a(
                .unwrap(analyticsEvent, { _ in
                        .data(named: "action", value: "click->panel-button#click")
                }),
                .href(linkUrl),
                .div(
                    .class("body"),
                    bodyNode
                ),
                .unwrap(cta, { cta in
                        .div(
                            .class("cta"),
                            .text("\(cta) &rarr;")
                        )
                })
            )
        )
    }

    static func publishedTime(_ publishedAt: Date, label: String) -> Self {
        .time(
            .datetime(DateFormatter.yearMonthDayDateFormatter.string(from: publishedAt)),
            .group(
                .text(label),
                .text(" "),
                .text(DateFormatter.mediumDateFormatter.string(from: publishedAt))
            )
        )
    }

    static func spiFrontEndDebugPanel(dataItems: [PublicPage.FrontEndDebugPanelDataItem]) -> Node<HTML.BodyContext> {
        .element(named: "spi-debug-panel", nodes: [
            .class("hidden"),
            .table(
                .tbody(
                    .group(
                        dataItems.map({ dataItem -> Node<HTML.TableContext> in
                                .tr(
                                    .attribute(named: "server-side"),
                                    .td(
                                        .text(dataItem.title)
                                    ),
                                    .td(
                                        .text(dataItem.value)
                                    )
                                )
                        })
                    )
                )
            )
        ])
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

    static func packageListItem(linkUrl: String,
                                packageName: String,
                                summary: String?,
                                matchingKeywords: [String]? = nil,
                                repositoryOwner: String,
                                repositoryName: String,
                                stars: Int?,
                                lastActivityAt: Date?,
                                hasDocs: Bool) -> Self {
        @Dependency(\.date.now) var now
        return .li(
            .a(
                .href(linkUrl),
                .h4(.text(packageName)),
                .unwrap(summary) { .p(.text($0)) },
                .unwrap(matchingKeywords) { keywords in
                    .if(keywords.count > 0,
                        .ul(
                            .class("keywords matching"),
                            .li(
                                .span(
                                    .text("Matching keywords: ")
                                )
                            ),
                            .group(
                                keywords.map { keyword in
                                        .li(
                                            .span(
                                                .text(keyword)
                                            )
                                        )
                                }
                            )
                        )
                    )
                },
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
                                .text("Active \(date: $0, relativeTo: now)")
                            )
                        )
                    },
                    .unwrap(stars) {
                        .starsListItem(numberOfStars: $0)
                    },
                    .if (hasDocs,
                        .li(.class("has-documentation"),
                            .small(
                                .text("Has documentation")
                            )
                        )
                    )
                )
            )
        )
    }
}

extension Node where Context == HTML.AnchorContext {

    static func podcastPanelBody(includeHeading: Bool) -> Self {
        .group(
            .if(includeHeading, .h3("The Swift Package Indexing Podcast")),
            .text("Join Dave and Sven for a chat about ongoing Swift Package Index development and package recommendations from the community on the Swift Package Indexing podcast.")
        )
    }

    static func sponsorsCtaBody() -> Node<HTML.AnchorContext> {
        .group(
            .text("Join the companies and individuals who support this site and keep it running."),
            .div(
                .class("avatars"),
                .forEach(Supporters.community.randomSample(count: 27), { sponsor in
                        .img(
                            .src(sponsor.avatarUrl),
                            .unwrap(sponsor.name, { .title($0) }),
                            .alt("Profile picture for \(sponsor.name ?? sponsor.login)"),
                            .width(20),
                            .height(20)
                        )
                })
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

// Custom data types used by Plot extensions

struct TabMetadata: Equatable {
    let id: String
    let title: String
}
