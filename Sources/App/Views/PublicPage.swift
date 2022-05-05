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
import Vapor
import Plot

class PublicPage {
    
    let path: String
    
    init(path: String) {
        self.path = path
    }
    
    /// The page's full HTML document.
    /// - Returns: A fully formed page inside a <html> element.
    final func document() -> HTML {
        HTML(
            .lang(.english),
            .comment("Version: \(Current.appVersion())"),
            .comment("DB Id: \(Current.dbId())"),
            head(),
            body()
        )
    }
    
    /// The page head.
    /// - Returns: A <head> element.
    final func head() -> Node<HTML.DocumentContext> {
        .head(
            metaNoIndex(),
            .viewport(.accordingToDevice, initialScale: 1),
            .meta(.charset(.utf8)),
            .siteName("The Swift Package Index"),
            .url(SiteURL.absoluteURL(path)),
            .title(title()),
            .description(description()),
            .twitterCardType(.summary),
            .socialImageLink(SiteURL.images("logo.png").absoluteURL()),
            .favicon(SiteURL.images("logo-small.png").relativeURL()),
            .link(
                .rel(.stylesheet),
                .href(SiteURL.stylesheets("main").relativeURL() + "?" + ResourceReloadIdentifier.value),
                .data(named: "turbolinks-track", value: "reload")
            ),
            .link(
                .rel(.alternate),
                .type("application/rss+xml"),
                .title("Swift Package Index – Recently Added"),
                .href(SiteURL.rssPackages.absoluteURL())
            ),
            .link(
                .rel(.alternate),
                .type("application/rss+xml"),
                .title("Swift Package Index – Recent Releases"),
                .href(SiteURL.rssReleases.absoluteURL())
            ),
            .link(
                .rel(.alternate),
                .type("application/rss+xml"),
                .title("Swift Package Index – Recent Major Releases"),
                .href(SiteURL.rssReleases.absoluteURL(parameters: [QueryParameter(key: "major", value: "true")]))
            ),
            .link(
                .rel(.alternate),
                .type("application/rss+xml"),
                .title("Swift Package Index – Recent Major & Minor Releases"),
                .href(SiteURL.rssReleases.absoluteURL(parameters: [QueryParameter(key: "major", value: "true"), QueryParameter(key: "minor", value: "true")]))
            ),
            .link(
                .rel(.alternate),
                .type("application/rss+xml"),
                .title("Swift Package Index – Recent Pre-Releases"),
                .href(SiteURL.rssReleases.absoluteURL(parameters: [QueryParameter(key: "pre", value: "true")]))
            ),
            .script(
                .src(SiteURL.javascripts("main").relativeURL() + "?" + ResourceReloadIdentifier.value),
                .data(named: "turbolinks-track", value: "reload"),
                .defer()
            ),
            analyticsHead()
        )
    }
    
    /// For non-production environments, if a search engine requests the page, tell it not to index it.
    /// - Returns: Either nothing, or a <meta> element telling search engines not to index this content.
    final func metaNoIndex() -> Node<HTML.HeadContext> {
        return .if(Environment.current != .production,
                   .meta(
                    .name("robots"),
                    .content("noindex")
                   ))
    }
    
    /// The Plausible analytics code to be inserted into the <head> element.
    /// - Returns: A <script> containing the Plausible script tags.
    final func analyticsHead() -> Node<HTML.HeadContext> {
        return .if(Environment.current == .production, .raw(PublicPage.analyticsScriptTags))
    }

    static var analyticsScriptTags: String {
        """
        <script async defer data-domain="swiftpackageindex.com" src="https://plausible.io/js/plausible.outbound-links.js"></script>
        <script>window.plausible = window.plausible || function() { (window.plausible.q = window.plausible.q || []).push(arguments) }</script>
        """
    }

    /// The full page title, including the site name.
    /// - Returns: A string with the fully formed page title, ready for use in a <title> element.
    final func title() -> String {
        guard let pageTitle = pageTitle()
        else { return "Swift Package Index" }
        
        return "\(pageTitle) &ndash; Swift Package Index"
    }
    
    /// The title for the current page.
    /// - Returns: A string with a custom page title, if one is desired.
    func pageTitle() -> String? {
        nil
    }
    
    /// The page description, or a default page description if none is specified.
    /// - Returns: A string with the fully formed page description, ready for use in a meta tag.
    final func description(maxLength: Int = 200) -> String {
        guard let pageDescription = pageDescription() else {
            return """
            The Swift Package Index is the place to find the best Swift packages.
            """
        }
        
        if pageDescription.count >= maxLength - 1 {
            return pageDescription.prefix(maxLength - 1) + "…"
        } else {
            return pageDescription
        }
    }
    
    /// The description for the current page.
    /// - Returns: A string with a custom page description, if one is desired.
    func pageDescription() -> String? {
        nil
    }
    
    /// A CSS class name to add to the <body> element.
    /// - Returns: A string with one or more CSS class names.
    func bodyClass() -> String? {
        nil
    }
    
    /// The page body.
    /// - Returns: A <body> element.
    final func body() -> Node<HTML.DocumentContext> {
        .body(
            .class(bodyClass() ?? ""),
            preBody(),
            bodyComments(),
            stagingBanner(),
            header(),
            preMain(),
            breadcrumbNode(),
            main(),
            postMain(),
            footer(),
            stagingBanner(),
            postBody()
        )
    }
    
    /// Any page level HTML comments for hidden metadata.
    /// - Returns: An element, or `group` of elements.
    func bodyComments() -> Node<HTML.BodyContext> {
        .empty
    }
    
    /// A staging banner, which only appears on the staging/development server.
    /// - Returns: Either a <div> element, or nothing.
    final func stagingBanner() -> Node<HTML.BodyContext> {
        guard !Current.hideStagingBanner() else { return .empty }
        if Environment.current == .development {
            return .div(
                .class("staging"),
                .text("Staging / Development")
            )
        } else {
            return .empty
        }
    }
    
    /// The site header, including the site navigation.
    /// - Returns: A <header> element.
    final func header() -> Node<HTML.BodyContext> {
        .header(
            .div(
                .class("inner"),
                .a(
                    .href(SiteURL.home.relativeURL()),
                    .h1(
                        .img(
                            .alt("The Swift Package Index logo."),
                            .src(SiteURL.images("logo.svg").relativeURL())
                        ),
                        "Swift Package Index"
                    )
                ),
                .nav(
                    .ul(
                        .group(navMenuItems().map { $0.listNode() })
                    )
                )
            )
        )
    }
    
    /// The items to be rendered in the site navigation menu.
    /// - Returns: An array of `NavMenuItem` items used in `header`.
    func navMenuItems() -> [NavMenuItem] {
        [.sponsorCTA, .addPackage, .blog, .faq, .search]
    }

    /// Optional content that will be inserted in between the page header and the main content for the page.
    /// - Returns: An optional element, or group of elements.
    func preMain() -> Node<HTML.BodyContext> {
        .empty
    }
    
    /// The breadcrumb bar for overall site navigation.
    /// - Returns: An optional element, or group of elements.
    func breadcrumbs() -> [Breadcrumb] {
        []
    }

    private func breadcrumbNode() -> Node<HTML.BodyContext> {
        let breadcrumbs = breadcrumbs()
        guard breadcrumbs.count > 0 else { return .empty }

        return .nav(
            .class("breadcrumbs"),
            .div(
                .class("inner"),
                .ul(
                    .group(breadcrumbs.map { $0.listNode() })
                )
            )
        )
    }

    /// The <main> element that will contain the primary content for the page.
    /// - Returns: A <main> element.
    final func main() -> Node<HTML.BodyContext> {
        .main(
            .div(
                .class("inner"),
                content()
            )
        )
    }
    
    /// Optional content that will be inserted in between the main content for the page and the page footer.
    /// - Returns: An optional element, or group of elements.
    func postMain() -> Node<HTML.BodyContext> {
        .empty
    }
    
    /// Optional content that will be inserted just after the start of the body.
    /// - Returns: An optional element, or group of elements.
    func preBody() -> Node<HTML.BodyContext> {
        .empty
    }
    
    /// Optional content that will be inserted just before the end of the body.
    /// - Returns: An optional element, or group of elements.
    func postBody() -> Node<HTML.BodyContext> {
        .empty
    }
    
    /// The page's content.
    /// - Returns: A node, or nodes (in a `.group`) with the page's content.
    func content() -> Node<HTML.BodyContext> {
        .p(
            "Override ",
            .code("content()"),
            " to change this page's content."
        )
    }
    
    /// The site footer, including all footer links.
    /// - Returns: A <footer> element.
    final func footer() -> Node<HTML.BodyContext> {
        .footer(
            .div(
                .class("inner"),
                .nav(
                    .ul(
                        .li(
                            .a(
                                .href(ExternalURL.projectBlog),
                                "Blog"
                            )
                        ),
                        .li(
                            .a(
                                .href(ExternalURL.projectGitHub),
                                "GitHub"
                            )
                        ),
                        .li(
                            .a(
                                .href(SiteURL.privacy.relativeURL()),
                                "Privacy and Cookies"
                            )
                        ),
                        .li(
                            .a(
                                .href("https://swiftpackageindex.statuspage.io"),
                                "Uptime and System Status"
                            )
                        ),
                        .li(
                            .a(
                                .href(SiteURL.buildMonitor.relativeURL()),
                                "Build System Monitor"
                            )
                        ),
                        .li(
                            .a(
                                .href("https://twitter.com/swiftpackages"),
                                "Twitter"
                            )
                        )
                    ),
                    .small(
                        .text("The Swift Package Index is entirely funded by community sponsorship. Thank you to "),
                        .a(
                            .href("https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server#funding-and-sponsorship"),
                            "all our sponsors for their generosity"
                        ),
                        .text(".")
                    )
                )
            )
        )
    }
    
}
