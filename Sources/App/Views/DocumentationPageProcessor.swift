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

import Vapor
import SwiftSoup
import Plot

struct DocumentationPageProcessor {
    let document: SwiftSoup.Document
    let repositoryOwner: String
    let repositoryOwnerName: String
    let repositoryName: String
    let packageName: String
    let docVersion: DocVersion
    let referenceLatest: Version.Kind?
    let referenceKind: Version.Kind
    let canonicalUrl: String?
    let availableArchives: [AvailableArchive]
    let availableVersions: [AvailableDocumentationVersion]
    let updatedAt: Date

    struct AvailableArchive {
        let archive: DocArchive
        let isCurrent: Bool

        var name: String { archive.name }
        var title: String { archive.title }
    }

    struct AvailableDocumentationVersion {
        let kind: Version.Kind
        let reference: String
        let docArchives: [DocArchive]
        let isLatestStable: Bool
    }

    init?(repositoryOwner: String,
          repositoryOwnerName: String,
          repositoryName: String,
          packageName: String,
          docVersion: DocVersion,
          referenceLatest: Version.Kind?,
          referenceKind: Version.Kind,
          canonicalUrl: String?,
          availableArchives: [AvailableArchive],
          availableVersions: [AvailableDocumentationVersion],
          updatedAt: Date,
          rawHtml: String) {
        self.repositoryOwner = repositoryOwner
        self.repositoryOwnerName = repositoryOwnerName
        self.repositoryName = repositoryName
        self.packageName = packageName
        self.docVersion = docVersion
        self.referenceLatest = referenceLatest
        self.referenceKind = referenceKind
        self.canonicalUrl = canonicalUrl
        self.availableArchives = availableArchives
        self.availableVersions = availableVersions
        self.updatedAt = updatedAt

        do {
            document = try SwiftSoup.parse(rawHtml)

            try Self.rewriteBaseUrls(document: document, owner: repositoryOwner, repository: repositoryName, docVersion: docVersion)

            // SPI related modifications
            try document.title("\(packageName) Documentation – Swift Package Index")
            if let metaNoIndex = self.metaNoIndex {
                try document.head()?.prepend(metaNoIndex)
            }
            try document.head()?.append(self.stylesheetLinks)
            try document.head()?.append(self.javascriptLinks)
            if let canonicalUrl = self.canonicalUrl {
                try document.head()?.append(
                    // We should not use Plot's `url` helper here as some of the DocC JavaScript
                    // lowercases both the `og:url` and `twitter:url` properties, if present. It's
                    // better to have no `og:url` and `twitter:url` properties than incorrect ones.
                    Plot.Node.link(
                        .rel(.canonical),
                        .href(canonicalUrl)
                    ).render()
                )
            }
            try document.body()?.prepend(self.header)
            try document.body()?.append(self.footer)
            try document.body()?.append(self.frontEndDebugPanel)
            if let analyticsScript = self.analyticsScript {
                try document.head()?.append(analyticsScript)
            }
        } catch {
            return nil
        }
    }

    var metaNoIndex: String? {
        guard Current.environment() != .production else { return nil }
        return Plot.Node.meta(
            .name("robots"),
            .content("noindex")
        ).render()
    }

    var stylesheetLinks: String {
        Plot.Node.group(["docc", "shared"].map { stylesheetName -> Plot.Node<HTML.HeadContext> in
                .link(
                    .rel(.stylesheet),
                    .href(SiteURL.stylesheets(stylesheetName).relativeURL() + "?" + ResourceReloadIdentifier.value)
                )
        }).render()
    }

    var javascriptLinks: String {
        Plot.Node<HTML.HeadContext>.script(
            .src(SiteURL.javascripts("shared").relativeURL() + "?" + ResourceReloadIdentifier.value),
            .data(named: "turbolinks-track", value: "reload"),
            .defer()
        ).render()
    }

    var analyticsScript: String? {
        guard Current.environment() == .production else { return nil }
        return PublicPage.analyticsScriptTags
    }

    var header: String {
        let documentationVersionChoices: [Plot.Node<HTML.ListContext>] = availableVersions.compactMap { version in
            // If a version has no docArchives, it has no documentation we can switch to.
            guard let currentArchive = availableArchives.first(where: { $0.isCurrent })
            else { return nil }

            return .li(
                .if(version.reference == docVersion.reference, .class("current")),
                .a(
                    .href(
                        SiteURL.relativeURL(
                            owner: repositoryOwner,
                            repository: repositoryName,
                            documentation: .internal(docVersion: .reference(version.reference),
                                                     archive: currentArchive.name),
                            fragment: .documentation
                        )
                    ),
                    .span(
                        .class(version.kind.cssClass),
                        .text(version.reference)
                    )
                )
            )
        }

        var breadcrumbs = [
            Breadcrumb(title: "Swift Package Index", url: SiteURL.home.relativeURL()),
            Breadcrumb(title: repositoryOwnerName, url: SiteURL.author(.value(repositoryOwner)).relativeURL()),
            Breadcrumb(title: packageName, url: SiteURL.package(.value(repositoryOwner), .value(repositoryName), .none).relativeURL()),
            Breadcrumb(title: .init(
                .text("Documentation for "),
                .span(
                    .class(referenceKind.cssClass),
                    .text(docVersion.reference)
                )
            ), choices: documentationVersionChoices.count > 0 ? documentationVersionChoices : nil)
        ]

        if availableArchives.count > 1,
           let currentArchive = availableArchives.first(where: { $0.isCurrent }) {
            breadcrumbs.append(Breadcrumb(title: currentArchive.title, choices: [
                .forEach(availableArchives, { archive in
                        .li(
                            .if(archive.isCurrent, .class("current")),
                            .a(
                                .href(
                                    SiteURL.relativeURL(
                                        owner: repositoryOwner,
                                        repository: repositoryName,
                                        documentation: .internal(docVersion: docVersion, archive: archive.name),
                                        fragment: .documentation
                                    )
                                ),
                                .text(archive.title)
                            )
                        )
                })
            ]))
        }

#warning("The 'View latest release documentation' needs changing too.")
        return Plot.Node.group(
            .header(
                .class("spi"),
                .if(Current.environment() == .development, stagingBanner()),
                .div(
                    .class("inner breadcrumbs"),
                    .nav(
                        .ul(
                            .group(breadcrumbs.map { $0.listNode() })
                        )
                    )
                ),
                .if(referenceLatest != .release,
                    // Only try and show a link to the latest stable if there *is* a latest stable.
                    .unwrap(availableVersions.first(where: \.isLatestStable)) { latestStable in
                            .div(
                                .class("latest-stable-wrap"),
                                .div(
                                    .class("inner latest-stable"),
                                    .text(latestStableLinkExplanatoryText),
                                    .text(" "),
                                    .unwrap(latestStable.docArchives.first) { docArchive in
                                            .group(
                                                .a(
                                                    .href(
                                                        SiteURL.relativeURL(
                                                            owner: repositoryOwner,
                                                            repository: repositoryName,
                                                            documentation: .internal(docVersion: .reference(latestStable.reference),
                                                                                     archive: docArchive.name),
                                                            fragment: .documentation
                                                        )
                                                    ),
                                                    .text("View latest release documentation")
                                                ),
                                                .text(".")
                                            )
                                    }
                                )
                            )
                    })
            )
        ).render()
    }

    var footer: String {
        return Plot.Node.footer(
            .class("spi"),
            .div(
                .class("inner"),
                .publishedTime(updatedAt, label: "Last updated on"),
                .nav(
                    .ul(
                        .li(
                            .a(
                                .href(SiteURL.blog.relativeURL()),
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
                                .href(ExternalURL.mastodon),
                                "Mastodon"
                            )
                        )
                    )
                ),
                .small(
                    .text("The Swift Package Index is entirely funded by sponsorship. Thank you to "),
                    .a(
                        .href("https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server#funding-and-sponsorship"),
                        "all our sponsors for their generosity"
                    ),
                    .text(".")
                )
            ),
            .if(Current.environment() == .development, stagingBanner())
        ).render()
    }

    var frontEndDebugPanel: String {
        Plot.Node<HTML.BodyContext>.spiFrontEndDebugPanel(dataItems: []).render()
    }

    var processedPage: String {
        do {
            return try document.html()
        } catch {
            return "An error occurred while rendering processed documentation."
        }
    }

    var latestStableLinkExplanatoryText: String {
        switch referenceKind {
            case .release: return "This documentation is from a previous release and may not reflect the latest released version."
            case .preRelease: return "This documentation is from a pre-release and may not reflect the latest released version."
            case .defaultBranch: return "This documentation is from the \(docVersion.reference) branch and may not reflect the latest released version."
        }
    }

    func stagingBanner() -> Plot.Node<HTML.BodyContext> {
        .div(
            .class("staging"),
            .text("This is a staging environment. For live and up-to-date documentation, "),
            .a(
                .href("https://swiftpackageindex.com"),
                "visit swiftpackageindex.com"
            ),
            .text(".")
        )
    }

    static func rewriteBaseUrls(document: SwiftSoup.Document, owner: String, repository: String, docVersion: DocVersion) throws {
        try rewriteScriptBaseUrl(document: document, owner: owner, repository: repository, docVersion: docVersion)
        try rewriteAttribute("href", document: document, owner: owner, repository: repository, docVersion: docVersion)
        try rewriteAttribute("src", document: document, owner: owner, repository: repository, docVersion: docVersion)
    }

    static func rewriteScriptBaseUrl(document: SwiftSoup.Document, owner: String, repository: String, docVersion: DocVersion) throws {
        // Possible rewrite strategies
        //   / -> /a/b/1.2.3        (toReference)
        //   / -> /a/b/~            (current)
        //   /a/b/1.2.3 -> /a/b/~   (current)
        switch docVersion {
            case .current(let reference):
                for e in try document.select("script") {
                    let value = e.data().trimmingCharacters(in: .whitespacesAndNewlines)
                    if value == #"var baseUrl = "/""# {
                        //   / -> /a/b/~            (current)
                        let path = "/\(owner)/\(repository)/\(String.current)/".lowercased()
                        try e.html(#"var baseUrl = "\#(path)""#)
                    }
                    if let reference {
                        let fullyQualifiedPrefix = "/\(owner)/\(repository)/\(reference)".lowercased()
                        if value == #"var baseUrl = "\#(fullyQualifiedPrefix)/""# {
                            //   /a/b/1.2.3 -> /a/b/~   (current)
                            let path = "/\(owner)/\(repository)/\(String.current)/".lowercased()
                            try e.html(#"var baseUrl = "\#(path)""#)
                        }
                    }
                }
            case .reference(let reference):
                //   / -> /a/b/1.2.3        (toReference)
                for e in try document.select("script") {
                    let value = e.data().trimmingCharacters(in: .whitespacesAndNewlines)
                    if value == #"var baseUrl = "/""# {
                        let path = "/\(owner)/\(repository)/\(reference)/".lowercased()
                        try e.html(#"var baseUrl = "\#(path)""#)
                    }
                }
        }
    }

    static func rewriteAttribute(_ attribute: String, document: SwiftSoup.Document, owner: String, repository: String, docVersion: DocVersion) throws {
        // Possible rewrite strategies
        //   / -> /a/b/1.2.3        (toReference)
        //   / -> /a/b/~            (current)
        //   /a/b/1.2.3 -> /a/b/~   (current)
        switch docVersion {
            case .current(let reference):
                for e in try document.select(#"[\#(attribute)^="/"]"#) {
                    let value = try e.attr(attribute)
                    if !value.lowercased().hasPrefix("/\(owner)/\(repository)/".lowercased()) {
                        // no /{owner}/{repo}/ prefix -> it's a dynamic base url resource, i.e. a "/" resource
                        //   / -> /a/b/~            (current)
                        try e.attr(attribute, "/\(owner)/\(repository)/\(String.current)\(value)".lowercased())
                    } else if let reference {
                        let fullyQualifiedPrefix = "/\(owner)/\(repository)/\(reference)".lowercased()
                        if value.lowercased().hasPrefix(fullyQualifiedPrefix) {
                            // matches expected fully qualified resource path
                            //   /a/b/1.2.3 -> /a/b/~   (current)
                            let trimmed = value.dropFirst(fullyQualifiedPrefix.count)
                            try e.attr(attribute, "/\(owner)/\(repository)/\(String.current)\(trimmed)".lowercased())
                        } else {
                            // did not match expected resource prefix - leave it alone
                            // (shouldn't be possible)
                            return
                        }
                    }
                }
            case .reference(let reference):
                //   / -> /a/b/1.2.3        (toReference)
                for e in try document.select(#"[\#(attribute)^="/"]"#) {
                    let value = try e.attr(attribute)
                    if !value.lowercased().hasPrefix("/\(owner)/\(repository)/".lowercased()) {
                        // no /{owner}/{repo}/ prefix -> it's a dynamic base url resource, i.e. a "/" resource
                        //   / -> /a/b/~            (current)
                        try e.attr(attribute, "/\(owner)/\(repository)/\(reference)\(value)".lowercased())
                    } else {
                        // already prefixed resource, leave it alone
                        return
                    }
                }
        }
    }
}


extension String {
    static let current = "~"
}

extension PathComponent {
    static let current: Self = "~"
}
