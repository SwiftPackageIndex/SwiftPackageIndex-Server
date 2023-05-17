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

import XCTest

@testable import App

import Ink
import Plot
import SPIManifest
import SnapshotTesting
import Vapor


class WebpageSnapshotTests: SnapshotTestCase {

    func test_HomeIndexView() throws {
        Supporters.mock()

        let page = { HomeIndex.View(path: "/", model: .mock).document() }

        assertSnapshot(matching: page, as: .html)
    }

    func test_PackageShowView() throws {
        // Work-around to set the local time zone for time sensitive
        // tests. Sets the explicit default time zone to UTC for the duration
        // of this test.
        let explicitGMTTimeZone = TimeZone(identifier: "Etc/UTC")!
        let oldDefault = NSTimeZone.default
        NSTimeZone.default = explicitGMTTimeZone
        defer {
            NSTimeZone.default = oldDefault
        }

        var model = API.PackageController.GetRoute.Model.mock
        model.homepageUrl = "https://swiftpackageindex.com/"
        let page = { PackageShow.View(path: "", model: model, packageSchema: .mock).document() }

        assertSnapshot(matching: page, as: .html)
    }

    func test_PackageShowView_binary_targets() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.homepageUrl = "https://swiftpackageindex.com/"
        model.hasBinaryTargets = true

        let page = { PackageShow.View(path: "", model: model, packageSchema: .mock).document() }

        assertSnapshot(matching: page, as: .html)
    }

    func test_PackageShowView_few_keywords() throws {

        // Work-around to set the local time zone for time sensitive
        // tests. Sets the explicit default time zone to UTC for the duration
        // of this test.
        let explicitGMTTimeZone = TimeZone(identifier: "Etc/UTC")!
        let oldDefault = NSTimeZone.default
        NSTimeZone.default = explicitGMTTimeZone
        defer {
            NSTimeZone.default = oldDefault
        }

        var model = API.PackageController.GetRoute.Model.mock
        let keywordsWithCounts = [("tag1", 1),
                                  ("tag2", 10),
                                  ("tag3", 100),
                                  ("tag4", 1000),
                                  ("tag5", 1234)]

        model.keywords = keywordsWithCounts.map { $0.0 }
        model.weightedKeywords = keywordsWithCounts.map(WeightedKeyword.init)

        let page = { PackageShow.View(path: "", model: model, packageSchema: .mock).document() }

        assertSnapshot(matching: page, as: .html)
    }

    func test_PackageShowView_many_keywords() throws {

        // Work-around to set the local time zone for time sensitive
        // tests. Sets the explicit default time zone to UTC for the duration
        // of this test.
        let explicitGMTTimeZone = TimeZone(identifier: "Etc/UTC")!
        let oldDefault = NSTimeZone.default
        NSTimeZone.default = explicitGMTTimeZone
        defer {
            NSTimeZone.default = oldDefault
        }

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

        assertSnapshot(matching: page, as: .html)
    }

    func test_PackageShowView_emoji_summary() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.summary = ":package: Nothing but Cache. :octocat:"

        let page = { PackageShow.View(path: "", model: model, packageSchema: .mock).document() }

        assertSnapshot(matching: page, as: .html)
    }

    func test_PackageShowView_open_source_license() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.license = .mit
        model.licenseUrl = "https://example.com/license.html"

        let page = { PackageShow.View(path: "", model: model, packageSchema: .mock).document() }
        assertSnapshot(matching: page, as: .html)
    }

    func test_PackageShowView_app_store_incompatible_license() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.license = .gpl_3_0
        model.licenseUrl = "https://example.com/license.html"

        let page = { PackageShow.View(path: "", model: model, packageSchema: .mock).document() }
        assertSnapshot(matching: page, as: .html)
    }

    func test_PackageShowView_other_license() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.license = .other
        model.licenseUrl = "https://example.com/license.html"

        let page = { PackageShow.View(path: "", model: model, packageSchema: .mock).document() }
        assertSnapshot(matching: page, as: .html)
    }

    func test_PackageShowView_no_license() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.license = .none
        model.licenseUrl = nil

        let page = { PackageShow.View(path: "", model: model, packageSchema: .mock).document() }
        assertSnapshot(matching: page, as: .html)
    }

    func test_PackageShowView_no_authors_activity() throws {
        // Test to ensure we don't display empty bullet points when there is
        // no author or activity info
        var model = API.PackageController.GetRoute.Model.mock
        model.authors = nil
        model.activity = nil
        let page = { PackageShow.View(path: "", model: model, packageSchema: .mock).document() }

        assertSnapshot(matching: page, as: .html)
    }

    func test_PackageShowView_with_documentation_link() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.hasDocumentation = true
        let page = { PackageShow.View(path: "", model: model, packageSchema: .mock).document() }

        assertSnapshot(matching: page, as: .html)
    }

    func test_PackageShowView_single_row_tables() throws {
        // Test display when all three significant version collapse to a single row
        var model = API.PackageController.GetRoute.Model.mock
        do {
            let compatible = API.PackageController.GetRoute.Model.SwiftVersionResults(
                status5_5: .compatible,
                status5_6: .compatible,
                status5_7: .compatible,
                status5_8: .compatible
            )
            model.swiftVersionBuildInfo = .init(
                stable: .init(referenceName: "5.2.5", results: compatible),
                beta: .init(referenceName: "6.0.0-b1", results: compatible),
                latest: .init(referenceName: "main", results: compatible)
            )
        }
        do {
            let compatible = API.PackageController.GetRoute.Model.PlatformResults(
                iosStatus: .compatible,
                linuxStatus: .compatible,
                macosStatus: .compatible,
                tvosStatus: .compatible,
                watchosStatus: .compatible
            )
            model.platformBuildInfo = .init(
                stable: .init(referenceName: "5.2.5", results: compatible),
                beta: .init(referenceName: "6.0.0-b1", results: compatible),
                latest: .init(referenceName: "main", results: compatible)
            )
        }
        let page = { PackageShow.View(path: "", model: model, packageSchema: .mock).document() }

        assertSnapshot(matching: page, as: .html)
    }

    func test_PackageShowView_no_builds() throws {
        // Test display when there are no builds
        var model = API.PackageController.GetRoute.Model.mock
        model.swiftVersionBuildInfo = .init(stable: nil, beta: nil, latest: nil)
        model.platformBuildInfo = .init(stable: nil, beta: nil, latest: nil)
        let page = { PackageShow.View(path: "", model: model, packageSchema: .mock).document() }

        assertSnapshot(matching: page, as: .html)
    }

    func test_PackageShowView_missingPackage() throws {
        let page = { MissingPackage.View(path: "", model: .mock).document() }
        assertSnapshot(matching: page, as: .html)
    }

    func test_PackageReadmeView() throws {
        let model = PackageReadme.Model.mock
        let page = { PackageReadme.View(model: model).document() }

        assertSnapshot(matching: page, as: .html)
    }

    // Note: This snapshot test deliberately omits an image snapshot as the HTML being tested has no explicit styling.
    func test_PackageReadmeView_unparseableReadme_noImageSnapshots() throws {
        let model = PackageReadme.Model(url: "https://example.com/owner/repo/README", readme: nil)
        let page = { PackageReadme.View(model: model).document() }

        assertSnapshot(matching: page, as: .html)
    }

    // Note: This snapshot test deliberately omits an image snapshot as the HTML being tested has no explicit styling.
    func test_PackageReadmeView_noReadme_noImageSnapshots() throws {
        let model = PackageReadme.Model(url: nil, readme: nil)
        let page = { PackageReadme.View(model: model).document() }

        assertSnapshot(matching: page, as: .html)
    }

    func test_PackageReleasesView() throws {
        let model = PackageReleases.Model.mock
        let page = { PackageReleases.View(model: model).document() }

        assertSnapshot(matching: page, as: .html)
    }

    func test_PackageReleasesView_NoModel() throws {
        let page = { PackageReleases.View(model: nil).document() }

        assertSnapshot(matching: page, as: .html)
    }

    func test_ErrorPageView() throws {
        let page = { ErrorPage.View(path: "", error: Abort(.notFound)).document() }

        assertSnapshot(matching: page, as: .html)
    }

    func test_MarkdownPage() throws {
        let page = { MarkdownPage(path: "", "privacy.md").document() }

        assertSnapshot(matching: page, as: .html)
    }

    func test_MarkdownPageStyling() throws {
        let data = try XCTUnwrap(try fixtureData(for: "markdown-test.md"))
        let markdown = try XCTUnwrap(String(data: data, encoding: .utf8))
        let html = MarkdownParser().parse(markdown).html
        let page = { MarkdownPage(path: "", html: html).document() }

        assertSnapshot(matching: page, as: .html)
    }

    func test_BuildIndex() throws {
        let page = { BuildIndex.View(path: "", model: .mock).document() }

        assertSnapshot(matching: page, as: .html)
    }

    func test_BuildShow() throws {
        let page = { BuildShow.View(path: "", model: .mock).document() }

        assertSnapshot(matching: page, as: .html)
    }

    func test_BuildMonitorIndex() throws {
        let page = { BuildMonitorIndex.View(path: "", builds: .mock).document() }

        assertSnapshot(matching: page, as: .html)
    }

    func test_MaintainerInfoIndex() throws {
        let page = { MaintainerInfoIndex.View(path: "", model: .mock).document() }

        assertSnapshot(matching: page, as: .html)
    }

    func test_AuthorShow() throws {
        let page = { AuthorShow.View(path: "", model: .mock).document() }

        assertSnapshot(matching: page, as: .html)
    }

    func test_SearchShow() throws {
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
                    lastActivityAt: Current.date().adding(hours: -28),
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
                    lastActivityAt: Current.date().adding(hours: -52),
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
                    lastActivityAt: Current.date().adding(hours: -76),
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
                    lastActivityAt: Current.date().adding(hours: -76),
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

        assertSnapshot(matching: page, as: .html)
    }

    func test_SearchShow_withFilters() throws {
        let page = { SearchShow.View(path: "", model: .mockWithFilter()).document() }

        assertSnapshot(matching: page, as: .html)
    }

    func test_SearchShow_withXSSAttempt() throws {
        let page = { SearchShow.View(path: "/search?query=%27%3E%22%3E%3C/script%3E%3Csvg/onload=confirm(%27XSS%27)%3E",
                                     model: .mockWithXSS()).document() }

        assertSnapshot(matching: page, as: .html)
    }

    func test_KeywordShow() throws {
        let page = { KeywordShow.View(path: "", model: .mock).document() }

        assertSnapshot(matching: page, as: .html)
    }

    func test_DocCTemplate() throws {
        let doccTemplatePath = fixturesDirectory().appendingPathComponent("docc-template.html").path
        let doccHtml = try String(contentsOfFile: doccTemplatePath)
        let archive = DocArchive(name: "archive1", title: "Archive1")
        let processor = try XCTUnwrap(DocumentationPageProcessor(repositoryOwner: "owner",
                                                                 repositoryOwnerName: "Owner Name",
                                                                 repositoryName: "package",
                                                                 packageName: "Package Name",
                                                                 reference: "main",
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

        assertSnapshot(matching: processor.processedPage, as: .html)
    }

    func test_DocCTemplate_outdatedStableVersion() throws {
        let doccTemplatePath = fixturesDirectory().appendingPathComponent("docc-template.html").path
        let doccHtml = try String(contentsOfFile: doccTemplatePath)
        let archive = DocArchive(name: "archive1", title: "Archive1")
        let processor = try XCTUnwrap(DocumentationPageProcessor(repositoryOwner: "owner",
                                                                 repositoryOwnerName: "Owner Name",
                                                                 repositoryName: "package",
                                                                 packageName: "Package Name",
                                                                 reference: "1.1.0",
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

        assertSnapshot(matching: processor.processedPage, as: .html)
    }

    func test_DocCTemplate_multipleVersions() throws {
        let doccTemplatePath = fixturesDirectory().appendingPathComponent("docc-template.html").path
        let doccHtml = try String(contentsOfFile: doccTemplatePath)
        let archive1 = DocArchive(name: "archive1", title: "Archive1")
        let archive2 = DocArchive(name: "archive2", title: "Archive2")
        let processor = try XCTUnwrap(DocumentationPageProcessor(repositoryOwner: "owner",
                                                                 repositoryOwnerName: "Owner Name",
                                                                 repositoryName: "package",
                                                                 packageName: "Package Name",
                                                                 reference: "main",
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

        assertSnapshot(matching: processor.processedPage, as: .html)
    }

    func test_SupportersShow() throws {
        Supporters.mock()

        let model = SupportersShow.Model()
        let page = { SupportersShow.View(path: "", model: model).document() }

        assertSnapshot(matching: page, as: .html)
    }

    func test_ValidateSPIManifest_show() throws {
        let manifest = try SPIManifest.Manifest(yml: ValidateSPIManifest.Model.placeholderManifest)
        let model = ValidateSPIManifest.Model(validationResult: .valid(manifest))
        let page = { ValidateSPIManifest.View(path: "", model: model).document() }

        assertSnapshot(matching: page, as: .html)
    }
}
