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

import Vapor
import SwiftSoup
import Plot

struct DocumentationPageProcessor {
    let document: SwiftSoup.Document
    let repositoryOwner: String
    let repositoryOwnerName: String
    let repositoryName: String
    let packageName: String
    let reference: String
    let referenceKind: Version.Kind?
    let docArchives: [String]
    let allAvailableDocumentationVersions: [AvailableDocumentationVersion]

    struct AvailableDocumentationVersion {
        let kind: Version.Kind
        let reference: String
        let docArchives: [String]
        let isLatestStable: Bool
    }

    init?(repositoryOwner: String,
          repositoryOwnerName: String,
          repositoryName: String,
          packageName: String,
          reference: String,
          referenceKind: Version.Kind?,
          docArchives: [String],
          allAvailableDocumentationVersions: [AvailableDocumentationVersion],
          rawHtml: String) {
        self.repositoryOwner = repositoryOwner
        self.repositoryOwnerName = repositoryOwnerName
        self.repositoryName = repositoryName
        self.packageName = packageName
        self.reference = reference
        self.referenceKind = referenceKind
        self.docArchives = docArchives
        self.allAvailableDocumentationVersions = allAvailableDocumentationVersions

        do {
            document = try SwiftSoup.parse(rawHtml)
            try document.head()?.append(self.stylesheetLink)
            try document.body()?.prepend(self.header)
            try document.body()?.append(self.footer)
            if let analyticsScript = self.analyticsScript {
                try document.head()?.append(analyticsScript)
            }
        } catch {
            return nil
        }
    }

    var stylesheetLink: String {
        Plot.Node.link(
            .rel(.stylesheet),
            .href(SiteURL.stylesheets("docc").relativeURL() + "?" + ResourceReloadIdentifier.value)
        ).render()
    }

    var analyticsScript: String? {
        guard Environment.current == .production else { return nil }
        return PublicPage.analyticsScriptTags
    }

    var header: String {
        let navMenuItems: [NavMenuItem] = [.addPackage, .blog, .faq, .searchLink]

        let documentationVersionChoices: [Plot.Node<HTML.ListContext>] = allAvailableDocumentationVersions.compactMap { version in
            // If a version has no docArchives, it has no documentation we can switch to.
            guard let firstDocArchive = docArchives.first else { return nil }

            return .li(
                .a(
                    .href(relativeDocumentationURL(reference: version.reference, docArchive: firstDocArchive)),
                    .span(
                        .class(version.kind.cssClass),
                        .text(version.reference)
                    )
                )
            )
        }

        var breadcrumbs = [
            Breadcrumb(title: "Home", url: SiteURL.home.relativeURL()),
            Breadcrumb(title: repositoryOwnerName, url: SiteURL.author(.value(repositoryOwner)).relativeURL()),
            Breadcrumb(title: packageName, url: SiteURL.package(.value(repositoryOwner), .value(repositoryName), .none).relativeURL())
        ]
        
        if (Environment.current == .development) {
            breadcrumbs.append(Breadcrumb(title: .init(
                .text("Documentation for "),
                .unwrap(referenceKind, { referenceKind in
                        .span(
                            .class(referenceKind.cssClass),
                            .text(reference)
                        )
                }, else: .text(reference))
            ), choices: documentationVersionChoices.count > 0 ? documentationVersionChoices : nil))
        } else {
            breadcrumbs.append(Breadcrumb(title: "Documentation"))
        }

        return Plot.Node.group(
            .header(
                .class("spi"),
                .div(
                    .class("inner branding_and_menu"),
                    .a(
                        .href("/"),
                        .h1(
                            .img(
                                .src("/images/logo.svg"),
                                .alt("Swift Package Index Logo")
                            ),
                            .text("Swift Package Index")
                        )
                    ),
                    .nav(
                        .class("menu"),
                        .ul(
                            .group(navMenuItems.map { $0.listNode() })
                        )
                    )
                ),
                .div(
                    .class("inner breadcrumbs"),
                    .nav(
                        .ul(
                            .group(breadcrumbs.map { $0.listNode() })
                        )
                    )
                ),
                .if(referenceKind != .release,
                    // Only try and show a link to the latest stable if there *is* a latest stable.
                    .unwrap(allAvailableDocumentationVersions.latestStableVersion) { latestStable in
                            .div(
                                .class("latest_stable_wrap"),
                                .div(
                                    .class("inner latest_stable"),
                                    .text(latestStableLinkExplanatoryText),
                                    .text(" "),
                                    .unwrap(latestStable.docArchives.first) { docArchive in
                                            .group(
                                                .a(
                                                    .href(relativeDocumentationURL(reference: latestStable.reference,
                                                                                   docArchive: docArchive)),
                                                    .text("View latest stable docs")
                                                ),
                                                .text(".")
                                            )
                                    }
                                )
                            )
                    }
                ),
                .if(docArchives.count > 1, .div(
                    .class("doc_archives_wrap"),
                    .div(
                        .class("inner doc_archives"),
                        .nav(
                            .ul(
                                .li(
                                    .text("Documentation for:")
                                ),
                                .forEach(docArchives, { archive in
                                        .li(
                                            .a(
                                                .href(relativeDocumentationURL(reference:reference, docArchive: archive)),
                                                .text(archive)
                                            )
                                        )
                                })
                            )
                        )
                    ))
                )
            )
        ).render()
    }

    var footer: String {
        return Plot.Node.footer(
            .class("spi"),
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
                                .href("https://twitter.com/swiftpackages"),
                                "Twitter"
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
                )
            )
        ).render()
    }

    var processedPage: String {
        do {
            return try document.html()
        } catch {
            return "An error occurred while rendering processed documentation."
        }
    }

    // Note: When this gets merged back with the refactored SiteURL, note that it's duplicated in `PackageShow.Model`.
    func relativeDocumentationURL(reference: String, docArchive: String) -> String {
        "/\(repositoryOwner)/\(repositoryName)/\(reference)/documentation/\(docArchive.lowercased())"
    }

    var latestStableLinkExplanatoryText: String {
        if referenceKind == .defaultBranch {
            return "This documentation is from the \(packageName) default branch and may not reflect the latest stable release."
        } else {
            return "This is documentation from an old version of \(packageName)."
        }
    }
}

extension Array where Element == DocumentationPageProcessor.AvailableDocumentationVersion {
    var latestStableVersion: DocumentationPageProcessor.AvailableDocumentationVersion? {
        self.filter { $0.kind == .release }.first
    }
}
