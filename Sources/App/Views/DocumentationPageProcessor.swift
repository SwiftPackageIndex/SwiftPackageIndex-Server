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
    let referenceLatest: Version.Kind?
    let referenceKind: Version.Kind
    let availableArchives: [AvailableArchive]
    let availableVersions: [AvailableDocumentationVersion]
    let updatedAt: Date

    struct AvailableArchive {
        let name: String
        let isCurrent: Bool
    }

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
          referenceLatest: Version.Kind?,
          referenceKind: Version.Kind,
          availableArchives: [AvailableArchive],
          availableVersions: [AvailableDocumentationVersion],
          updatedAt: Date,
          rawHtml: String) {
        self.repositoryOwner = repositoryOwner
        self.repositoryOwnerName = repositoryOwnerName
        self.repositoryName = repositoryName
        self.packageName = packageName
        self.reference = reference
        self.referenceLatest = referenceLatest
        self.referenceKind = referenceKind
        self.availableArchives = availableArchives
        self.availableVersions = availableVersions
        self.updatedAt = updatedAt

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
        let documentationVersionChoices: [Plot.Node<HTML.ListContext>] = availableVersions.compactMap { version in
            // If a version has no docArchives, it has no documentation we can switch to.
            guard let currentArchive = availableArchives.first(where: { $0.isCurrent })
            else { return nil }

            return .li(
                .if(version.reference == reference, .class("current")),
                .a(
                    .href(Self.relativeDocumentationURL(owner: repositoryOwner,
                                                        repository: repositoryName,
                                                        reference: version.reference,
                                                        docArchive: currentArchive.name)),
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
                    .text(reference)
                )
            ), choices: documentationVersionChoices.count > 0 ? documentationVersionChoices : nil)
        ]

        if availableArchives.count > 1,
           let currentArchive = availableArchives.first(where: { $0.isCurrent }) {
            breadcrumbs.append(Breadcrumb(title: currentArchive.name, choices: [
                .forEach(availableArchives, { archive in
                        .li(
                            .if(archive.isCurrent, .class("current")),
                            .a(
                                .href(Self.relativeDocumentationURL(owner: repositoryOwner,
                                                                    repository: repositoryName,
                                                                    reference: reference,
                                                                    docArchive: archive.name)),
                                .text(archive.name)
                            )
                        )
                })
            ]))
        }

        return Plot.Node.group(
            .header(
                .class("spi"),
                .if(Environment.current == .development, stagingBanner()),
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
                                                    .href(Self.relativeDocumentationURL(owner:repositoryOwner,
                                                                                        repository: repositoryName,
                                                                                        reference: latestStable.reference,
                                                                                        docArchive: docArchive)),
                                                    .text("View latest documentation")
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
                .small(
                    .text("Last updated on "),
                    .text(DateFormatter.lastUpdatedOnFormatter.string(from:updatedAt))
                ),
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
            .if(Environment.current == .development, stagingBanner())
        ).render()
    }

    var processedPage: String {
        do {
            return try document.html()
        } catch {
            return "An error occurred while rendering processed documentation."
        }
    }

    // TODO: Merge this back with SiteURL at some point.
    static func relativeDocumentationURL(owner: String, repository: String, reference: String, docArchive: String) -> String {
        "/\(owner)/\(repository)/\(reference)/documentation/\(docArchive.lowercased())"
    }

    var latestStableLinkExplanatoryText: String {
        switch referenceKind {
            case .release: return "This documentation is from a previous release and may not reflect the latest version."
            case .preRelease: return "This documentation is from a pre-release and may not reflect the latest version."
            case .defaultBranch: return "This documentation is from the \(reference) branch and may not reflect the latest version."
        }
    }

    func stagingBanner() -> Plot.Node<HTML.BodyContext> {
        .div(
            .class("staging"),
            .text("Staging / Development")
        )
    }
}
