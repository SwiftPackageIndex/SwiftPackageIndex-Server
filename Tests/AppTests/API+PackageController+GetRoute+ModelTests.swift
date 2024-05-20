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

import XCTVapor
import SnapshotTesting
import SPIManifest


class API_PackageController_GetRoute_ModelTests: SnapshotTestCase {
    typealias PackageResult = PackageController.PackageResult

    func test_init_no_packageName() async throws {
        // Tests behaviour when we're lacking data
        // setup package without package name
        let pkg = try savePackage(on: app.db, "1".url)
        try await Repository(package: pkg, name: "bar", owner: "foo").save(on: app.db)
        let version = try App.Version(package: pkg,
                                      latest: .defaultBranch,
                                      packageName: nil,
                                      reference: .branch("main"))
        try await version.save(on: app.db)
        let pr = try await PackageResult.query(on: app.db, owner: "foo", repository: "bar")

        // MUT
        let m = API.PackageController.GetRoute.Model(result: pr,
                                                     history: nil,
                                                     products: [],
                                                     targets: [],
                                                     swiftVersionBuildInfo: nil,
                                                     platformBuildInfo: nil,
                                                     weightedKeywords: [],
                                                     swift6Readiness: nil)

        // validate
        XCTAssertNotNil(m)
        XCTAssertEqual(m?.title, "bar")
    }

    func test_init_packageIdentity() async throws {
        let pkg = try savePackage(on: app.db, URL(string: "https://github.com/foo/swift-bar.git")!)
        try await Repository(package: pkg, name: "bar", owner: "foo").save(on: app.db)
        let version = try App.Version(package: pkg, latest: .defaultBranch, packageName: nil, reference: .branch("main"))
        try await version.save(on: app.db)
        let packageResult = try await PackageResult.query(on: app.db, owner: "foo", repository: "bar")

        // MUT
        let model = try XCTUnwrap(API.PackageController.GetRoute.Model(result: packageResult,
                                                                       history: nil,
                                                                       products: [],
                                                                       targets: [],
                                                                       swiftVersionBuildInfo: nil,
                                                                       platformBuildInfo: nil,
                                                                       weightedKeywords: [],
                                                                       swift6Readiness: nil))

        // validate
        XCTAssertEqual(model.packageIdentity, "swift-bar")
    }

    func test_init_generated_documentation() async throws {
        let pkg = try savePackage(on: app.db, "1".url)
        try await Repository(package: pkg, name: "bar", owner: "foo").save(on: app.db)
        let version = try App.Version(package: pkg, latest: .defaultBranch, packageName: nil, reference: .branch("main"))
        version.docArchives = [.init(name: "archive1", title: "Archive One")]
        try await version.save(on: app.db)
        let packageResult = try await PackageResult.query(on: app.db, owner: "foo", repository: "bar")

        // MUT
        let model = try XCTUnwrap(API.PackageController.GetRoute.Model(result: packageResult,
                                                                       history: nil,
                                                                       products: [],
                                                                       targets: [],
                                                                       swiftVersionBuildInfo: nil,
                                                                       platformBuildInfo: nil,
                                                                       weightedKeywords: [],
                                                                       swift6Readiness: nil))

        // validate
        XCTAssertEqual(model.currentDocumentationTarget, .internal(docVersion: .current(referencing: nil), archive: "archive1"))
    }

    func test_init_external_documentation() async throws {
        let pkg = try savePackage(on: app.db, "1".url)
        try await Repository(package: pkg, name: "bar", owner: "foo").save(on: app.db)
        let version = try App.Version(package: pkg, latest: .defaultBranch, packageName: nil, reference: .branch("main"))
        version.spiManifest = .init(externalLinks: .init(documentation: "https://example.com/package/documentation"))
        try await version.save(on: app.db)
        let packageResult = try await PackageResult.query(on: app.db, owner: "foo", repository: "bar")

        // MUT
        let model = try XCTUnwrap(API.PackageController.GetRoute.Model(result: packageResult,
                                                                       history: nil,
                                                                       products: [],
                                                                       targets: [],
                                                                       swiftVersionBuildInfo: nil,
                                                                       platformBuildInfo: nil,
                                                                       weightedKeywords: [],
                                                                       swift6Readiness: nil))

        // validate
        XCTAssertEqual(model.currentDocumentationTarget, .external(url: "https://example.com/package/documentation"))
    }

    func test_gitHubOwnerUrl() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.repositoryOwner = "owner"
        XCTAssertEqual(model.gitHubOwnerUrl, "https://github.com/owner")
    }

    func test_gitHubRepositoryUrl() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.repositoryOwner = "owner"
        model.repositoryName = "repository"
        XCTAssertEqual(model.gitHubRepositoryUrl, "https://github.com/owner/repository")
    }

    func test_history() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.history = .init(
            createdAt: Calendar.current.date(byAdding: .month, value: -7, to: Current.date())!,
            commitCount: 12,
            commitCountURL: "https://example.com/commits.html",
            releaseCount: 2,
            releaseCountURL: "https://example.com/releases.html"
        )

        let renderedHistory = model.historyListItem().render(indentedBy: .spaces(2))
        assertSnapshot(of: renderedHistory, as: .lines)
    }

    func test_binary_targets() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.hasBinaryTargets = true
        model.licenseUrl = "<license-url-here>"

        let renderedBinaryOnly = model.binaryTargetsItem().render(indentedBy: .spaces(2))
        assertSnapshot(of: renderedBinaryOnly, as: .lines)
    }

    func test_binary_targets_no_license() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.hasBinaryTargets = true
        model.licenseUrl = nil

        let renderedBinaryOnly = model.binaryTargetsItem().render(indentedBy: .spaces(2))
        assertSnapshot(of: renderedBinaryOnly, as: .lines)
    }

    func test_history_archived_package() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.history = .init(
            createdAt: Calendar.current.date(byAdding: .month, value: -7, to: Current.date())!,
            commitCount: 12,
            commitCountURL: "https://example.com/commits.html",
            releaseCount: 2,
            releaseCountURL: "https://example.com/releases.html"
        )
        model.isArchived = true

        let renderedHistory = model.historyListItem().render(indentedBy: .spaces(2))
        assertSnapshot(of: renderedHistory, as: .lines)
    }

    func test_archived_warning_line_for_active_package() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.isArchived = false

        let renderedHistory = model.archivedListItem().render(indentedBy: .spaces(2))
        assertSnapshot(of: renderedHistory, as: .lines)
    }

    func test_archived_warning_line_for_archived_package() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.isArchived = true

        let renderedHistory = model.archivedListItem().render(indentedBy: .spaces(2))
        assertSnapshot(of: renderedHistory, as: .lines)
    }

    func test_activity_variants__missing_open_issue() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.activity?.openIssuesURL = nil

        let renderedActivity = model.activityListItem().render(indentedBy: .spaces(2))
        assertSnapshot(of: renderedActivity, as: .lines)
    }

    func test_activity_variants__missing_open_PRs() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.activity?.openPullRequestsURL = nil

        let renderedActivity = model.activityListItem().render(indentedBy: .spaces(2))
        assertSnapshot(of: renderedActivity, as: .lines)
    }

    func test_activity_variants__missing_open_issues_and_PRs() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.activity?.openIssuesURL = nil
        model.activity?.openPullRequestsURL = nil

        let renderedActivity = model.activityListItem().render(indentedBy: .spaces(2))
        assertSnapshot(of: renderedActivity, as: .lines)
    }

    func test_activity_variants__missing_last_closed_issue() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.activity?.lastIssueClosedAt = nil

        let renderedActivity = model.activityListItem().render(indentedBy: .spaces(2))
        assertSnapshot(of: renderedActivity, as: .lines)
    }

    func test_activity_variants__missing_last_closed_PR() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.activity?.lastPullRequestClosedAt = nil

        let renderedActivity = model.activityListItem().render(indentedBy: .spaces(2))
        assertSnapshot(of: renderedActivity, as: .lines)
    }

    func test_activity_variants__missing_last_closed_issue_and_PR() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.activity?.lastIssueClosedAt = nil
        model.activity?.lastPullRequestClosedAt = nil

        let renderedActivity = model.activityListItem().render(indentedBy: .spaces(2))
        assertSnapshot(of: renderedActivity, as: .lines)
    }

    func test_activity_variants__missing_everything() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.activity?.openIssuesURL = nil
        model.activity?.openPullRequestsURL = nil
        model.activity?.lastIssueClosedAt = nil
        model.activity?.lastPullRequestClosedAt = nil

        XCTAssertEqual(model.activityListItem().render(), "")
    }

    func test_dependenciesPhrase_with_dependencies() throws {
        let model = API.PackageController.GetRoute.Model.mock
        XCTAssertEqual(model.dependenciesPhrase(), "This package depends on 2 other packages.")
    }

    func test_dependenciesPhrase_no_dependencies() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.dependencies = []
        XCTAssertEqual(model.dependenciesPhrase(), "This package has no package dependencies.")
    }

    func test_dependenciesPhrase_nil_dependencies() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.dependencies = nil
        XCTAssertEqual(model.dependenciesPhrase(), nil)
    }

    func test_stars_formatting() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.stars = 999
        XCTAssertEqual(model.starsListItem().render(), "<li class=\"stars\">999 stars</li>")
        model.stars = 1_000
        XCTAssertEqual(model.starsListItem().render(), "<li class=\"stars\">1,000 stars</li>")
        model.stars = 1_000_000
        XCTAssertEqual(model.starsListItem().render(), "<li class=\"stars\">1,000,000 stars</li>")
    }

    func test_productTypeListItem_formatting() throws {
        var model = API.PackageController.GetRoute.Model.mock

        // Libraries and plurality
        model.products = []
        XCTAssertEqual(model.productTypeListItem(.library).render(), "<li class=\"libraries\">No libraries</li>")

        model.products = [.init(name: "lib1", type: .library)]
        XCTAssertEqual(model.productTypeListItem(.library).render(), "<li class=\"libraries\">1 library</li>")

        model.products = [.init(name: "lib1", type: .library), .init(name: "lib2", type: .library)]
        XCTAssertEqual(model.productTypeListItem(.library).render(), "<li class=\"libraries\">2 libraries</li>")

        // Executables and Plugins
        model.products = [.init(name: "exe1", type: .executable), .init(name: "exe2", type: .executable)]
        XCTAssertEqual(model.productTypeListItem(.executable).render(), "<li class=\"executables\">2 executables</li>")

        model.products = [.init(name: "plg1", type: .plugin), .init(name: "plg2", type: .plugin)]
        XCTAssertEqual(model.productTypeListItem(.plugin).render(), "<li class=\"plugins\">2 plugins</li>")
    }

    func test_targetTypeListItem_formatting() throws {
        var model = API.PackageController.GetRoute.Model.mock

        // Macros
        model.targets = []
        XCTAssertEqual(model.targetTypeListItem(.macro).render(), "<li class=\"macros\">No macros</li>")

        model.targets = [.init(name: "macro1", type: .macro)]
        XCTAssertEqual(model.targetTypeListItem(.macro).render(), "<li class=\"macros\">1 macro</li>")

        model.targets = [.init(name: "macro1", type: .macro), .init(name: "macro2", type: .macro)]
        XCTAssertEqual(model.targetTypeListItem(.macro).render(), "<li class=\"macros\">2 macros</li>")
    }

    func test_authorMetadata() throws {
        var model = API.PackageController.GetRoute.Model.mock

        model.authors = API.PackageController.GetRoute.Model.AuthorMetadata .fromGitRepository(PackageAuthors(authors: [
            Author(name: "Author One"),
            Author(name: "Author Two")
        ], numberOfContributors: 5))
        XCTAssertEqual(model.authorsListItem().render(), "<li class=\"authors\">Written by Author One, Author Two, and 5 other contributors.</li>")

        model.authors = API.PackageController.GetRoute.Model.AuthorMetadata
            .fromSPIManifest("By Author One, Author Two, and more!")
        XCTAssertEqual(model.authorsListItem().render(), "<li class=\"authors\">By Author One, Author Two, and more!</li>")
    }

    func test_BuildInfo_init() throws {
        // ensure nil propagation when all versions' values are nil
        // (the generic type is irrelevant, we're just using Int for simplicity)
        XCTAssertNil(BuildInfo<Int>.init(stable: nil, beta: nil, latest: nil))
        XCTAssertNotNil(BuildInfo<Int>.init(stable: .init(referenceName: "foo", results: 1),
                                            beta: nil,
                                            latest: nil))
    }

    func test_BuildInfo_SwiftVersion_compatibility() throws {
        typealias Results = CompatibilityMatrix.SwiftVersionCompatibility

        do {
            let info = BuildInfo(stable: .some(.init(referenceName: "1.2.3",
                                                     results: Results(results: [.v5_8: .compatible,
                                                                                .v5_9: .incompatible,
                                                                                .v5_10: .unknown,
                                                                                .v6_0: .compatible]))),
                                 beta: nil,
                                 latest: nil)
            XCTAssertEqual(info?.compatibility, [.v1, .v4])
        }
        do {
            let info = BuildInfo(stable: .some(.init(referenceName: "1.2.3",
                                                     results: Results(results: [.v5_8: .compatible,
                                                                                .v5_9: .incompatible,
                                                                                .v5_10: .unknown,
                                                                                .v6_0: .compatible]))),
                                 beta: .some(.init(referenceName: "1.2.3-b1",
                                                   results: Results(results: [.v5_8: .incompatible,
                                                                              .v5_9: .incompatible,
                                                                              .v5_10: .compatible,
                                                                              .v6_0: .unknown]))),
                                 latest: nil)
            XCTAssertEqual(info?.compatibility, [.v1, .v3, .v4])
        }
    }

    func test_BuildInfo_Platform_compatibility() throws {
        typealias Results = CompatibilityMatrix.PlatformCompatibility

        do {
            let info = BuildInfo(stable: .some(.init(referenceName: "1.2.3",
                                                     results: Results(results: [.iOS: .compatible,
                                                                                .linux: .incompatible,
                                                                                .macOS: .unknown,
                                                                                .tvOS: .unknown,
                                                                                .visionOS: .unknown,
                                                                                .watchOS: .compatible]))),
                                 beta: nil,
                                 latest: nil)
            XCTAssertEqual(info?.compatibility, [.iOS, .watchOS])
        }
        do {
            let info = BuildInfo(stable: .some(.init(referenceName: "1.2.3",
                                                     results: Results(results: [.iOS: .compatible,
                                                                                .linux: .incompatible,
                                                                                .macOS: .unknown,
                                                                                .tvOS: .unknown,
                                                                                .visionOS: .unknown,
                                                                                .watchOS: .compatible]))),
                                 beta: .some(.init(referenceName: "1.2.3-b1",
                                                   results: Results(results: [.iOS: .compatible,
                                                                              .linux: .incompatible,
                                                                              .macOS: .compatible,
                                                                              .tvOS: .unknown,
                                                                              .visionOS: .unknown,
                                                                              .watchOS: .unknown]))),
                                 latest: nil)
            XCTAssertEqual(info?.compatibility, [.iOS, .macOS, .watchOS])
        }
    }

    func test_groupBuildInfo() throws {
        let result1: BuildResults = .init(results: [.v5_8: .compatible,
                                                    .v5_9: .compatible,
                                                    .v5_10: .compatible,
                                                    .v6_0: .compatible])
        let result2: BuildResults = .init(results: [.v5_8: .compatible,
                                                    .v5_9: .incompatible,
                                                    .v5_10: .incompatible,
                                                    .v6_0: .incompatible])
        let result3: BuildResults = .init(results: [.v5_8: .unknown,
                                                    .v5_9: .unknown,
                                                    .v5_10: .unknown,
                                                    .v6_0: .unknown])
        do {  // three distinct groups
            let buildInfo: BuildInfo = .init(stable: .init(referenceName: "1.2.3", results: result1),
                                             beta: .init(referenceName: "2.0.0-b1", results: result2),
                                             latest: .init(referenceName: "main", results: result3))!

            // MUT
            let res = API.PackageController.GetRoute.Model.groupBuildInfo(buildInfo)

            // validate
            XCTAssertEqual(res, [
                .init(references: [.init(name: "1.2.3", kind: .release)], results: result1),
                .init(references: [.init(name: "2.0.0-b1", kind: .preRelease)], results: result2),
                .init(references: [.init(name: "main", kind: .defaultBranch)], results: result3),
            ])
        }

        do {  // stable and latest share the same result and should be grouped
            let buildInfo: BuildInfo = .init(stable: .init(referenceName: "1.2.3",
                                                           results: result1),
                                             beta: .init(referenceName: "2.0.0-b1",
                                                         results: result2),
                                             latest: .init(referenceName: "main",
                                                           results: result1))!

            // MUT
            let res = API.PackageController.GetRoute.Model.groupBuildInfo(buildInfo)

            // validate
            XCTAssertEqual(res, [
                .init(references: [.init(name: "1.2.3", kind: .release),
                                   .init(name: "main", kind: .defaultBranch)], results: result1),
                .init(references: [.init(name: "2.0.0-b1", kind: .preRelease)], results: result2),
            ])
        }
    }

    func test_languagePlatformInfo() async throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try await Repository(package: pkg,
                             defaultBranch: "default",
                             name: "bar",
                             owner: "foo").save(on: app.db)
        try await [
            try App.Version(package: pkg, reference: .branch("branch")),
            try App.Version(package: pkg,
                            commitDate: Current.date().adding(days: -1),
                            latest: .defaultBranch,
                            reference: .branch("default"),
                            supportedPlatforms: [.macos("10.15"), .ios("13")],
                            swiftVersions: ["5.2", "5.3"].asSwiftVersions),
            try App.Version(package: pkg, reference: .tag(.init(1, 2, 3))),
            try App.Version(package: pkg,
                            commitDate: Current.date().adding(days: -3),
                            latest: .release,
                            reference: .tag(.init(2, 1, 0)),
                            supportedPlatforms: [.macos("10.13"), .ios("10")],
                            swiftVersions: ["4", "5"].asSwiftVersions),
            try App.Version(package: pkg,
                            commitDate: Current.date().adding(days: -2),
                            latest: .preRelease,
                            reference: .tag(.init(3, 0, 0, "beta")),
                            supportedPlatforms: [.macos("10.14"), .ios("13")],
                            swiftVersions: ["5", "5.2"].asSwiftVersions),
        ].save(on: app.db)
        let pr = try await PackageResult.query(on: app.db,
                                               owner: "foo",
                                               repository: "bar")

        // MUT
        let lpInfo = API.PackageController.GetRoute.Model
            .languagePlatformInfo(packageUrl: "1",
                                  defaultBranchVersion: pr.defaultBranchVersion,
                                  releaseVersion: pr.releaseVersion,
                                  preReleaseVersion: pr.preReleaseVersion)

        // validate
        XCTAssertEqual(lpInfo.stable?.link, .init(label: "2.1.0",
                                                  url: "1/releases/tag/2.1.0"))
        XCTAssertEqual(lpInfo.stable?.swiftVersions, ["4", "5"])
        XCTAssertEqual(lpInfo.stable?.platforms, [.macos("10.13"), .ios("10")])

        XCTAssertEqual(lpInfo.beta?.link, .init(label: "3.0.0-beta",
                                                url: "1/releases/tag/3.0.0-beta"))
        XCTAssertEqual(lpInfo.beta?.swiftVersions, ["5", "5.2"])
        XCTAssertEqual(lpInfo.beta?.platforms, [.macos("10.14"), .ios("13")])

        XCTAssertEqual(lpInfo.latest?.link, .init(label: "default", url: "1"))
        XCTAssertEqual(lpInfo.latest?.swiftVersions, ["5.2", "5.3"])
        XCTAssertEqual(lpInfo.latest?.platforms, [.macos("10.15"), .ios("13")])
    }

    func test_packageDependencyCodeSnippet() {
        let releaseRefs: [App.Version.Kind: App.Reference] = [
            .release: .tag(5, 5, 0),
            .preRelease: .tag(6, 0, 0, "b1"),
            .defaultBranch: .branch("main")
        ]
        XCTAssertEqual(
            API.PackageController.GetRoute.Model.packageDependencyCodeSnippet(
                for: .preRelease,
                releaseReferences: releaseRefs,
                packageURL: "https://github.com/Alamofire/Alamofire.git"
            ),
            .init(label: "6.0.0-b1",
                  url: ".package(url: &quot;https://github.com/Alamofire/Alamofire.git&quot;, from: &quot;6.0.0-b1&quot;)")
        )
        XCTAssertEqual(
            API.PackageController.GetRoute.Model.packageDependencyCodeSnippet(
                for: .release,
                releaseReferences: releaseRefs,
                packageURL: "https://github.com/Alamofire/Alamofire.git"
            ),
            .init(label: "5.5.0",
                  url: ".package(url: &quot;https://github.com/Alamofire/Alamofire.git&quot;, from: &quot;5.5.0&quot;)")
        )
        XCTAssertEqual(
            API.PackageController.GetRoute.Model.packageDependencyCodeSnippet(
                for: .defaultBranch,
                releaseReferences: releaseRefs,
                packageURL: "https://github.com/Alamofire/Alamofire.git"
            ),
            .init(label: "main",
                  url: ".package(url: &quot;https://github.com/Alamofire/Alamofire.git&quot;, branch: &quot;main&quot;)")
        )
    }

    func test_Swift6Readiness_dataRaceSafety() {
        XCTAssertEqual(Swift6Readiness(errorCounts: [:]).dataRaceSafety, .unknown)
        XCTAssertEqual(Swift6Readiness(errorCounts: [.iOS: 1]).dataRaceSafety, .unsafe)
        XCTAssertEqual(Swift6Readiness(errorCounts: [.iOS: 1, .linux: 0]).dataRaceSafety, .safe)
    }

    func test_Swift6Readiness_title() {
        XCTAssertEqual(Swift6Readiness(errorCounts: [:]).title, "No data available")
        XCTAssertEqual(Swift6Readiness(errorCounts: [.iOS: 1]).title, """
            Error counts:
            iOS: 1
            """)
        XCTAssertEqual(Swift6Readiness(errorCounts: [.iOS: 1, .macosSpm: 0]).title, """
            Error counts:
            iOS: 1
            macOS (SPM): 0
            """)
    }

}


// local typealiases / references to make tests more readable
fileprivate typealias BuildInfo = API.PackageController.GetRoute.Model.BuildInfo
fileprivate typealias BuildResults = CompatibilityMatrix.SwiftVersionCompatibility
fileprivate typealias Swift6Readiness = API.PackageController.GetRoute.Model.Swift6Readiness
