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

@testable import App

import Dependencies
import Ink
import Plot
import SPIManifest
import SnapshotTesting
import Testing
import Vapor


private extension DependenciesProvider {
    static var `default`: Self {
      .init {
          $0.date.now = .t0
          $0.environment.current = { .production }
          $0.environment.dbId = { "db-id" }
          $0.environment.processingBuildBacklog = { false }
          $0.timeZone = .utc
      }
    }
}


extension AllTests {
    @Suite(.dependencies(.default)) struct WebpageSnapshotTests { }
}


extension AllTests.WebpageSnapshotTests {

    @Test func HomeIndex_document() throws {
        Supporters.mock()

        let page = { HomeIndex.View(path: "/", model: .mock).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func HomeIndex_document_development() throws {
        // Test home page to ensure the dev environment is showing the dev banner and `noindex` for robots
        withDependencies {
            $0.environment.current = { .development }
        } operation: {
            Supporters.mock()

            let page = { HomeIndex.View(path: "/", model: .mock).document() }

            assertSnapshot(of: page, as: .html)
        }
    }

    @Test func MaintenanceMessageIndex_document() throws {
        let maintenanceMessage = """
            # Server Maintenance
            
            We are currently performing an update to our database server.
            
            Service should be restored within a few minutes.
            """

        let model = MaintenanceMessageIndex.Model(markdown: maintenanceMessage)
        let page = { MaintenanceMessageIndex.View(path: "/", model: model).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func PackageShow_document() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.homepageUrl = "https://swiftpackageindex.com/"
        let page = { PackageShow.View(path: "", model: model, packageSchema: .mock).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func PackageShow_document_binary_targets() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.homepageUrl = "https://swiftpackageindex.com/"
        model.hasBinaryTargets = true

        let page = { PackageShow.View(path: "", model: model, packageSchema: .mock).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func PackageShow_document_few_keywords() throws {
        var model = API.PackageController.GetRoute.Model.mock
        let keywordsWithCounts = [("tag1", 1),
                                  ("tag2", 10),
                                  ("tag3", 100),
                                  ("tag4", 1000),
                                  ("tag5", 1234)]

        model.keywords = keywordsWithCounts.map { $0.0 }
        model.weightedKeywords = keywordsWithCounts.map(WeightedKeyword.init)

        let page = { PackageShow.View(path: "", model: model, packageSchema: .mock).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func PackageShow_document_many_keywords() throws {
        var model = API.PackageController.GetRoute.Model.mock
        let keywordsWithCounts = [("tag1", 1), ("tag2", 10), ("tag3", 100), ("tag4", 1000), ("tag5", 1234),
                                  ("tag6", 1250), ("tag7", 1249), ("tag8", 1251), ("tag9", 12345),

                                  ("tag10", 123456), ("tag11", 1234567), ("tag12", 7654321), ("tag13", 8765432),

                                  ("tag14", 1100), ("tag15", 2200), ("tag16", 3300), ("tag17", 4400), ("tag18", 5500),
                                  ("tag19", 6600), ("tag20", 7700), ("tag21", 8800), ("tag22", 9900),

                                  ("tag23", 1149), ("tag24", 1151), ("tag25", 2249), ("tag26", 2250), ("tag27", 3349),
                                  ("tag28", 3350), ("tag29", 4449), ("tag30", 4450), ("tag31", 5549), ("tag32", 5550),
                                  ("tag33", 6649), ("tag34", 6650), ("tag35", 7749), ("tag36", 7750), ("tag37", 8849),
                                  ("tag38", 8850), ("tag39", 9949), ("tag40", 9950)]

        model.keywords = keywordsWithCounts.map { $0.0 }
        model.weightedKeywords = keywordsWithCounts.map(WeightedKeyword.init)

        let page = { PackageShow.View(path: "", model: model, packageSchema: .mock).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func PackageShow_document_emoji_summary() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.summary = ":package: Nothing but Cache. :octocat:"

        let page = { PackageShow.View(path: "", model: model, packageSchema: .mock).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func PackageShow_document_open_source_license() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.license = .mit
        model.licenseUrl = "https://example.com/license.html"

        let page = { PackageShow.View(path: "", model: model, packageSchema: .mock).document() }
        assertSnapshot(of: page, as: .html)
    }

    @Test func PackageShow_document_app_store_incompatible_license() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.license = .gpl_3_0
        model.licenseUrl = "https://example.com/license.html"

        let page = { PackageShow.View(path: "", model: model, packageSchema: .mock).document() }
        assertSnapshot(of: page, as: .html)
    }

    @Test func PackageShow_document_other_license() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.license = .other
        model.licenseUrl = "https://example.com/license.html"

        let page = { PackageShow.View(path: "", model: model, packageSchema: .mock).document() }
        assertSnapshot(of: page, as: .html)
    }

    @Test func PackageShow_document_no_license() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.license = .none
        model.licenseUrl = nil

        let page = { PackageShow.View(path: "", model: model, packageSchema: .mock).document() }
        assertSnapshot(of: page, as: .html)
    }

    @Test func PackageShow_document_no_authors_activity() throws {
        // Test to ensure we don't display empty bullet points when there is
        // no author or activity info
        var model = API.PackageController.GetRoute.Model.mock
        model.authors = nil
        model.activity = nil
        let page = { PackageShow.View(path: "", model: model, packageSchema: .mock).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func PackageShow_document_withPackageFundingLinks() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.fundingLinks = [
            .init(platform: .gitHub, url: "https://github.com/sponsor-url"),
            .init(platform: .customUrl, url: "https://example.com/sponsor-url"),
            .init(platform: .customUrl, url: "https://www.example.com/sponsor-url"),
            .init(platform: .customUrl, url: "https://subdomain.example.com/sponsor-url"),
        ]
        let page = { PackageShow.View(path: "", model: model, packageSchema: .mock).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func PackageShow_document_with_documentation_link() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.documentationTarget = .internal(docVersion: .reference("main"), archive: "archive")
        let page = { PackageShow.View(path: "", model: model, packageSchema: .mock).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func PackageShow_document_single_row_tables() throws {
        // Test display when all three significant version collapse to a single row
        var model = API.PackageController.GetRoute.Model.mock
        do {
            let compatible = CompatibilityMatrix.SwiftVersionCompatibility(results: [.v1: .compatible,
                                                                                     .v2: .compatible,
                                                                                     .v3: .compatible,
                                                                                     .v4: .compatible])
            model.swiftVersionBuildInfo = .init(
                stable: .init(referenceName: "5.2.5", results: compatible),
                beta: .init(referenceName: "6.0.0-b1", results: compatible),
                latest: .init(referenceName: "main", results: compatible)
            )
        }
        do {
            let compatible = CompatibilityMatrix.PlatformCompatibility(results: [.iOS: .compatible,
                                                                                 .linux: .compatible,
                                                                                 .macOS: .compatible,
                                                                                 .tvOS: .compatible,
                                                                                 .visionOS: .compatible,
                                                                                 .watchOS: .compatible])
            model.platformBuildInfo = .init(
                stable: .init(referenceName: "5.2.5", results: compatible),
                beta: .init(referenceName: "6.0.0-b1", results: compatible),
                latest: .init(referenceName: "main", results: compatible)
            )
        }
        let page = { PackageShow.View(path: "", model: model, packageSchema: .mock).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func PackageShow_document_no_builds() throws {
        // Test display when there are no builds
        var model = API.PackageController.GetRoute.Model.mock
        model.swiftVersionBuildInfo = .init(stable: nil, beta: nil, latest: nil)
        model.platformBuildInfo = .init(stable: nil, beta: nil, latest: nil)
        let page = { PackageShow.View(path: "", model: model, packageSchema: .mock).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func PackageShow_document_canonicalURL_noImageSnapshots() throws {
        // In production, the owner and repository name in the view model are fetched from
        // the database and have canonical capitalisation.
        var model = API.PackageController.GetRoute.Model.mock
        model.repositoryOwner = "owner"
        model.repositoryName = "repo"
        let page = { PackageShow.View(path: "/OWNER/Repo", model: model, packageSchema: .mock).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func MissingPackage_document() throws {
        let page = { MissingPackage.View(path: "", model: .mock).document() }
        assertSnapshot(of: page, as: .html)
    }

    @Test func PackageReadme_document() throws {
        let model = PackageReadme.Model.mock
        let page = { PackageReadme.View(model: model).document() }

        assertSnapshot(of: page, as: .html)
    }

    // Note: This snapshot test deliberately omits an image snapshot as the HTML being tested has no explicit styling.
    @Test func PackageReadme_document_unparseableReadme_noImageSnapshots() throws {
        let model = PackageReadme.Model(url: "https://example.com/owner/repo/README",
                                        repositoryOwner: "owner",
                                        repositoryName: "repo",
                                        defaultBranch: "main",
                                        readme: "")
        let page = { PackageReadme.View(model: model).document() }

        assertSnapshot(of: page, as: .html)
    }

    // Note: This snapshot test deliberately omits an image snapshot as the HTML being tested has no explicit styling.
    @Test func PackageReadme_document_noReadme_noImageSnapshots() throws {
        let model = PackageReadme.Model.noReadme
        let page = { PackageReadme.View(model: model).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func PackageShow_document_customCollection() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.homepageUrl = "https://swiftpackageindex.com/"
        model.customCollections = [.init(key: "custom-collection",
                                         name: "Custom Collection",
                                         url: "https://github.com/foo/bar/list.json")]
        let page = { PackageShow.View(path: "", model: model, packageSchema: .mock).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func PackageReleases_document() throws {
        let model = PackageReleases.Model.mock
        let page = { PackageReleases.View(model: model).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func PackageReleases_document_NoModel() throws {
        let page = { PackageReleases.View(model: nil).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func ErrorPage_document() throws {
        let page = { ErrorPage.View(path: "", error: Abort(.notFound)).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func MarkdownPage_document() throws {
        let page = { MarkdownPage(path: "", "privacy.md").document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func MarkdownPage_document_styling() throws {
        let data = try fixtureData(for: "markdown-test.md")
        let markdown = try #require(String(data: data, encoding: .utf8))
        let html = MarkdownParser().parse(markdown).html
        let page = { MarkdownPage(path: "", html: html).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func BuildIndex_document() throws {
        let page = { BuildIndex.View(path: "", model: .mock).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func BuildShow_document() throws {
        let page = { BuildShow.View(path: "", model: .mock).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func BuildMonitorIndex_document() throws {
        let page = { BuildMonitorIndex.View(path: "", builds: .mock).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func MaintainerInfoIndex_document() throws {
        let page = { MaintainerInfoIndex.View(path: "", model: .mock).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func AuthorShow_document() throws {
        let page = { AuthorShow.View(path: "", model: .mock).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func SearchShow_document() throws {
        let packageResults: [Search.Result] = [
            .package(
                .init(
                    packageId: .id1,
                    packageName: "Package One",
                    packageURL: "https://example.com/package/one",
                    repositoryName: "one",
                    repositoryOwner: "package",
                    stars: 1111,
                    // 24 hours + 4 hours to take it firmly into "one day ago" for the snapshot.
                    lastActivityAt: .t0.adding(hours: -28),
                    summary: "This is a package filled with ones.",
                    keywords: ["one", "1"],
                    hasDocs: false
                )!
            ),
            .package(
                .init(
                    packageId: .id2,
                    packageName: "Package Two",
                    packageURL: "https://example.com/package/two",
                    repositoryName: "two",
                    repositoryOwner: "package",
                    stars: 2222,
                    // 48 hours + 4 hours to take it firmly into "two days ago" for the snapshot.
                    lastActivityAt: .t0.adding(hours: -52),
                    summary: "This is a package filled with twos.",
                    keywords: ["two", "2"],
                    hasDocs: false
                )!
            ),
            .package(
                .init(
                    packageId: .id3,
                    packageName: "Package Three",
                    packageURL: "https://example.com/package/three",
                    repositoryName: "three",
                    repositoryOwner: "package",
                    stars: 3333,
                    // 72 hours + 4 hours to take it firmly into "two days ago" for the snapshot.
                    lastActivityAt: .t0.adding(hours: -76),
                    summary: "This is a package filled with threes.",
                    keywords: ["three", "3"],
                    hasDocs: false
                )!
            ),
            .package(
                .init(
                    packageId: .id4,
                    packageName: nil, // Ensure that packages with no name display correctly.
                    packageURL: "https://example.com/package/four",
                    repositoryName: "four",
                    repositoryOwner: "package",
                    stars: 4444,
                    // 72 hours + 4 hours to take it firmly into "two days ago" for the snapshot.
                    lastActivityAt: .t0.adding(hours: -76),
                    summary: "This is a package filled with fours.",
                    keywords: ["four", "4"],
                    hasDocs: false
                )!
            )
        ]

        let keywordResults: [Search.Result] = [
            .keyword(.init(keyword: "one")),
            .keyword(.init(keyword: "two")),
            .keyword(.init(keyword: "three")),
            .keyword(.init(keyword: "four"))
        ]

        let mockResults: [Search.Result] = .mock(packageResults: packageResults, keywordResults: keywordResults)
        let page = { SearchShow.View(path: "/search?query=foo",
                                     model: .mock(results: mockResults)).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func SearchShow_document_withFilters() throws {
        let page = { SearchShow.View(path: "", model: .mockWithFilter()).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func SearchShow_document_withXSSAttempt() throws {
        let page = { SearchShow.View(path: "/search?query=%27%3E%22%3E%3C/script%3E%3Csvg/onload=confirm(%27XSS%27)%3E",
                                     model: .mockWithXSS()).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func KeywordShow_document() throws {
        let page = { KeywordShow.View(path: "", model: .mock).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func CustomCollectionShow_document() throws {
        let page = { CustomCollectionShow.View(path: "", model: .mock).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func DocCTemplate_processedPage() throws {
        let doccTemplatePath = fixturesDirectory().appendingPathComponent("docc-template.html").path
        let doccHtml = try String(contentsOfFile: doccTemplatePath, encoding: .utf8)
        let archive = DocArchive(name: "archive1", title: "Archive1")
        let processor = try #require(DocumentationPageProcessor(repositoryOwner: "owner",
                                                                 repositoryOwnerName: "Owner Name",
                                                                 repositoryName: "package",
                                                                 packageName: "Package Name",
                                                                 docVersion: .reference("main"),
                                                                 referenceLatest: .release,
                                                                 referenceKind: .release,
                                                                 canonicalUrl: nil,
                                                                 availableArchives: [
                                                                    .init(archive: archive, isCurrent: true)
                                                                 ],
                                                                 availableVersions: [
                                                                    .init(kind: .defaultBranch,
                                                                          reference: "main",
                                                                          docArchives: [archive],
                                                                          isLatestStable: false),
                                                                 ],
                                                                 updatedAt: Date(timeIntervalSince1970: 0),
                                                                 rawHtml: doccHtml))

        assertSnapshot(of: processor.processedPage, as: .html)
    }

    @Test func DocCTemplate_processedPage_outdatedStableVersion() throws {
        let doccTemplatePath = fixturesDirectory().appendingPathComponent("docc-template.html").path
        let doccHtml = try String(contentsOfFile: doccTemplatePath, encoding: .utf8)
        let archive = DocArchive(name: "archive1", title: "Archive1")
        let processor = try #require(DocumentationPageProcessor(repositoryOwner: "owner",
                                                                 repositoryOwnerName: "Owner Name",
                                                                 repositoryName: "package",
                                                                 packageName: "Package Name",
                                                                 docVersion: .reference("1.1.0"),
                                                                 referenceLatest: nil,
                                                                 referenceKind: .release,
                                                                 canonicalUrl: "https://example.com/owner/repo/canonical-ref",
                                                                 availableArchives: [
                                                                    .init(archive: archive, isCurrent: true)
                                                                 ],
                                                                 availableVersions: [
                                                                    .init(kind: .defaultBranch,
                                                                          reference: "main",
                                                                          docArchives: [archive],
                                                                          isLatestStable: false),
                                                                    .init(kind: .preRelease,
                                                                          reference: "2.0.0",
                                                                          docArchives: [archive],
                                                                          isLatestStable: true)
                                                                 ],
                                                                 updatedAt: Date(timeIntervalSince1970: 0),
                                                                 rawHtml: doccHtml))

        assertSnapshot(of: processor.processedPage, as: .html)
    }

    @Test func DocCTemplate_processedPage_multipleVersions() throws {
        let doccTemplatePath = fixturesDirectory().appendingPathComponent("docc-template.html").path
        let doccHtml = try String(contentsOfFile: doccTemplatePath, encoding: .utf8)
        let archive1 = DocArchive(name: "archive1", title: "Archive1")
        let archive2 = DocArchive(name: "archive2", title: "Archive2")
        let processor = try #require(DocumentationPageProcessor(repositoryOwner: "owner",
                                                                 repositoryOwnerName: "Owner Name",
                                                                 repositoryName: "package",
                                                                 packageName: "Package Name",
                                                                 docVersion: .reference("main"),
                                                                 referenceLatest: .defaultBranch,
                                                                 referenceKind: .defaultBranch,
                                                                 canonicalUrl: "https://example.com/owner/repo/canonical-ref",
                                                                 availableArchives: [
                                                                    .init(archive: archive1, isCurrent: true),
                                                                    .init(archive: archive2, isCurrent: false),
                                                                 ],
                                                                 availableVersions: [
                                                                    .init(kind: .defaultBranch,
                                                                          reference: "main",
                                                                          docArchives: [archive1, archive2],
                                                                          isLatestStable: false),
                                                                    .init(kind: .preRelease,
                                                                          reference: "1.0.0-beta1",
                                                                          docArchives: [archive1, archive2],
                                                                          isLatestStable: false),
                                                                    .init(kind: .release,
                                                                          reference: "1.0.1",
                                                                          docArchives: [archive1, archive2],
                                                                          isLatestStable: true)
                                                                 ],
                                                                 updatedAt: Date(timeIntervalSince1970: 0),
                                                                 rawHtml: doccHtml))

        assertSnapshot(of: processor.processedPage, as: .html)
    }

    @Test func SupportersShow_document() throws {
        Supporters.mock()

        let model = SupportersShow.Model()
        let page = { SupportersShow.View(path: "", model: model).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func ReadyForSwift6Show_document() throws {
        withDependencies {
            $0.fileManager.contents = { @Sendable path in
                switch path {
                    case _ where path.hasSuffix("rfs6-packages.json"):
                        return Data(
                            """
                            [
                              {
                                "id" : "all",
                                "name" : "All packages",
                                "total" : 3395,
                                "values" : [
                                  {
                                    "date" : "2024-05-04",
                                    "toolchainId" : "org.swift.600202404221a",
                                    "toolchainLabel" : "Swift 6.0 Development Snapshot 2024-04-22 (a)",
                                    "value" : 1295
                                  }
                                ]
                              }
                            ]
                            """.utf8
                        )
                    case _ where path.hasSuffix("rfs6-errors.json"):
                        return Data(
                            """
                            [
                              {
                                "id" : "all",
                                "name" : "All packages",
                                "total" : 3395,
                                "values" : [
                                  {
                                    "date" : "2024-05-04",
                                    "toolchainId" : "org.swift.600202404221a",
                                    "toolchainLabel" : "Swift 6.0 Development Snapshot 2024-04-22 (a)",
                                    "value" : 56911
                                  }
                                ]
                              }
                            ]
                            """.utf8
                        )
                    case _ where path.hasSuffix("rfs6-events.json"):
                        return Data(
                            """
                            [
                                {
                                    "date": "2024-06-10",
                                    "value": "Xcode 16 beta 1 released at WWDC '24"
                                }
                            ]
                            """.utf8
                        )
                    default:
                        return nil
                }
            }
        } operation: {
            let model = ReadyForSwift6Show.Model()
            let page = { ReadyForSwift6Show.View(path: "", model: model).document() }

            assertSnapshot(of: page, as: .html)
        }
    }

    @Test func ValidateSPIManifest_document() throws {
        let manifest = try SPIManifest.Manifest(yml: ValidateSPIManifest.Model.placeholderManifest)
        let model = ValidateSPIManifest.Model(validationResult: .valid(manifest))
        let page = { ValidateSPIManifest.View(path: "", model: model).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func BlogActions_Index_document() {
        Supporters.mock()
        let model = BlogActions.Model.mock
        let page = { BlogActions.Index.View(path: "", model: model).document() }

        assertSnapshot(of: page, as: .html)
    }

    @Test func BlogActions_Show_document() {
        withDependencies {
            $0.fileManager.contents = { @Sendable _ in
                """
                This is some Markdown with [a link](https://example.com) and some _formatting_.
                
                ![Two logos](/images/blog/swift-package-index-and-apple-logos.png)
                
                Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vestibulum ut ante vel diam sagittis hendrerit id eget nunc. Proin non ex eget dolor tristique lacinia placerat et turpis. In dui dui, malesuada eu lectus nec, rhoncus feugiat nisi. Fusce pulvinar neque quis rutrum ullamcorper. Aliquam erat volutpat. Aliquam et molestie velit. Suspendisse sollicitudin arcu lorem, tristique iaculis quam lobortis non. Vivamus in euismod velit. Proin justo arcu, placerat ac sapien sed, tempus aliquet ligula.  Pellentesque ultricies, diam eget porta maximus, massa metus sagittis tellus, in vehicula elit erat sed metus. In mattis arcu imperdiet placerat vehicula. Vestibulum elementum iaculis tortor, sed feugiat ante posuere quis. Sed hendrerit, nisl ut tristique tincidunt, odio neque interdum ex, eget consectetur lectus dui eget felis. Donec in viverra lectus. Nunc fringilla molestie nibh ac iaculis. Morbi ac risus ut tellus posuere laoreet. Donec vehicula non sapien et mattis. Phasellus iaculis lacinia ipsum, eget congue nisl ornare ac. Vestibulum nec nibh suscipit, facilisis risus id, sollicitudin quam. Pellentesque eu quam quis magna sollicitudin consequat ac varius massa. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Suspendisse et quam dui.  Nunc dapibus erat vel elementum facilisis. Quisque mollis, lacus sit amet tincidunt egestas, nunc purus viverra eros, ut vestibulum eros eros nec nulla. Morbi ultrices, arcu non volutpat tincidunt, orci justo commodo mi, vel scelerisque odio turpis nec velit. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Pellentesque luctus a nisi tristique ullamcorper. Nunc fermentum lorem eget augue eleifend interdum. Nullam tincidunt turpis euismod convallis pretium. Etiam accumsan fermentum consectetur. Maecenas est justo, vulputate finibus blandit pulvinar, malesuada sit amet tellus. Etiam quis mauris a nulla gravida placerat et imperdiet justo. Nullam vitae leo in velit viverra lobortis. Fusce lacinia quam erat.  Suspendisse ut metus magna. Vestibulum consectetur ligula at turpis tristique molestie. Nunc maximus tempor porta. Morbi in mauris vitae eros laoreet tincidunt feugiat vel lacus. Nullam dignissim non dolor sed fringilla. Morbi eget vestibulum odio, ac hendrerit massa. Nullam sodales bibendum purus, et convallis nulla facilisis vitae. Aliquam eget sem lacus.  Morbi hendrerit nec nibh vitae tristique. Aenean id erat sit amet justo commodo pharetra. Nam at erat accumsan, consectetur nunc sit amet, convallis nibh. Quisque semper ex orci, id vehicula magna ornare laoreet. Donec ac accumsan libero, non imperdiet dolor. Duis imperdiet tempor erat quis iaculis. Etiam eget sodales lacus, ac semper tortor. Aenean sed dolor nec dolor pretium placerat. Cras eleifend felis magna, nec elementum leo pharetra in. Nam enim nulla, sodales in eleifend ut, imperdiet eget neque. Praesent congue turpis sed felis maximus dapibus. Mauris efficitur nisi in euismod mattis. Nullam semper dui risus. Proin mollis interdum turpis, vestibulum tempor risus blandit faucibus. Nulla posuere sagittis ligula et commodo.
                """.data(using: .utf8)
            }
        } operation: {
            let model = BlogActions.Model.PostSummary.mock()
            let page = { BlogActions.Show.View(path: "", model: model).document() }
            
            assertSnapshot(of: page, as: .html)
        }
    }

}
