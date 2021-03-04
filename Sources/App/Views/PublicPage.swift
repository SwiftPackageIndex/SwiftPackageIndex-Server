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
            .comment("Version: \(appVersion)"),
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
            .favicon(SiteURL.images("logo-simple.png").relativeURL()),
            .link(
                .rel(.stylesheet),
                .href("https://cdnjs.cloudflare.com/ajax/libs/normalize/8.0.1/normalize.min.css")
            ),
            .link(
                .rel(.stylesheet),
                .href(SiteURL.stylesheets("main").relativeURL() + "?\(resourceReloadQueryString())")
            ),
            .link(
                .rel(.alternate),
                .type("application/rss+xml"),
                .attribute(named: "title", value: "Swift Package Index – Recently Added"),
                .href(SiteURL.rssPackages.absoluteURL())
            ),
            .link(
                .rel(.alternate),
                .type("application/rss+xml"),
                .attribute(named: "title", value: "Swift Package Index – Recent Releases"),
                .href(SiteURL.rssReleases.absoluteURL())
            ),
            .link(
                .rel(.alternate),
                .type("application/rss+xml"),
                .attribute(named: "title", value: "Swift Package Index – Recent Major Releases"),
                .href(SiteURL.rssReleases.absoluteURL(parameters: [QueryParameter(key: "major", value: "true")]))
            ),
            .link(
                .rel(.alternate),
                .type("application/rss+xml"),
                .attribute(named: "title", value: "Swift Package Index – Recent Major & Minor Releases"),
                .href(SiteURL.rssReleases.absoluteURL(parameters: [QueryParameter(key: "major", value: "true"), QueryParameter(key: "minor", value: "true")]))
            ),
            .link(
                .rel(.alternate),
                .type("application/rss+xml"),
                .attribute(named: "title", value: "Swift Package Index – Recent Pre-Releases"),
                .href(SiteURL.rssReleases.absoluteURL(parameters: [QueryParameter(key: "pre", value: "true")]))
            ),
            .script(
                .src(SiteURL.javascripts("main").relativeURL() + "?\(resourceReloadQueryString())")
            ),
            analyticsHead()
        )
    }
    
    /// For non-production environments, if a search engine requests the page, tell it not to index it.
    /// - Returns: Either nothing, or a <meta> element telling search engines not to index this content.
    final func metaNoIndex() -> Node<HTML.HeadContext> {
        let environment = (try? Environment.detect()) ?? .development
        return .if(environment != .production,
                   .meta(
                    .name("robots"),
                    .content("noindex")
                   ))
    }

    /// The Google Tag Manager code to be inserted into the <head> element.
    /// - Returns: A <script> containing the Google Tag Manager template code.
    final func analyticsHead() -> Node<HTML.HeadContext> {
        let environment = (try? Environment.detect()) ?? .development
        return .if(environment == .production,
                   .raw("""
                    <script async defer data-domain="swiftpackageindex.com" src="https://plausible.io/js/plausible.outbound-links.js"></script>
                    <script>window.plausible = window.plausible || function() { (window.plausible.q = window.plausible.q || []).push(arguments) }</script>
                    """))
    }

    /// A query string that will force resources to reload CSS/JS resources change.
    /// - Returns: A string containing the query string.
    final func resourceReloadQueryString() -> String {

        // This method is only called in a local development environment, so all paths
        // can be relative to this source file.
        func modificationDate(forLocalResource resource: String) -> Date {
            let relativePathToPublic = "../../../Public/"
            let url = URL(fileURLWithPath: relativePathToPublic + resource,
                relativeTo: URL(fileURLWithPath: #file))

            // Assume the file has been modified *now* if the file can't be found.
            guard let attributes = try? Foundation.FileManager.default.attributesOfItem(atPath: url.path)
            else { return Date() }

            // Also assume the file is modified now if the attribute doesn't exist.
            let modificationDate = attributes[FileAttributeKey.modificationDate] as? Date
            return modificationDate ?? Date()
        }


        // In staging or production appVersion will be set to a commit hash, or a tag name.
        // It will only ever be nil when running in a local development environment.
        if let appVersion = appVersion {
            return appVersion
        } else {
            // Running under test? It's annoying to need to update snapshots every time the CSS or JS is saved.
            if let _ = NSClassFromString("XCTest") { return "test" }

            // Return the date of the most recently modified between the JavaScript and CSS resources.
            let jsModificationDate = modificationDate(forLocalResource: "main.js")
            let cssModificationDate = modificationDate(forLocalResource: "main.css")
            let latestModificationDate = max(jsModificationDate, cssModificationDate)
            return String(Int(latestModificationDate.timeIntervalSince1970))
        }
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
            bodyComments(),
            stagingBanner(),
            header(),
            noScript(),
            preMain(),
            main(),
            postMain(),
            footer(),
            stagingBanner()
        )
    }

    /// Any page level HTML comments for hidden metadata.
    /// - Returns: An element, or `group` of elements.
    func bodyComments() -> Node<HTML.BodyContext> {
        .empty
    }
    
    /// A stagig banner, which only appears on the staging/development server.
    /// - Returns: Either a <div> element, or nothing.
    final func stagingBanner() -> Node<HTML.BodyContext> {
        guard !Current.hideStagingBanner() else { return .empty }
        let environment = (try? Environment.detect()) ?? .development
        if environment == .development {
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
                        .img(.src(SiteURL.images("logo.svg").relativeURL())),
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
    
    /// A <noscript> element that will only be shown to people with JavaScript disabled.
    /// - Returns: A <noscript> element.
    func noScript() -> Node<HTML.BodyContext> {
        .empty
    }
    
    /// Optional content that will be inserted in between the page header and the main content for the page.
    /// - Returns: An optional element, or group of elements.
    func preMain() -> Node<HTML.BodyContext> {
        .empty
    }
    
    /// The <main> element that will contain the primary content for the page.
    /// - Returns: A <main> element.
    final func main() -> Node<HTML.BodyContext> {
        .main(
            .div(.class("inner"),
                 content()
            )
        )
    }
    
    /// Optional content that will be inserted in between the main content for the page and the page footer.
    /// - Returns: An optional element, or group of elements.
    func postMain() -> Node<HTML.BodyContext> {
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
            .div(.class("inner"),
                 .nav(
                    .ul(
                        .li(
                            .a(
                                .href("https://blog.swiftpackageindex.com"),
                                "Blog"
                            )
                        ),
                        .li(
                            .a(
                                .href("https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server"),
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
                                .href("https://twitter.com/swiftpackages"),
                                "Twitter"
                            )
                        )
                    ),
                    .element(named: "small", nodes: [ // TODO: Fix after Plot update
                        .text("Kindly hosted by"),
                        .a(
                            .href("https://macstadium.com/"),
                            "MacStadium"
                        )
                    ])
                 )
            )
        )
    }
    
}
