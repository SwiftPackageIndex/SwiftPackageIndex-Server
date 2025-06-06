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
import SPIManifest
import SnapshotTesting
import Testing
import Vapor


extension AllTests.API_PackageController_GetRoute_ModelTests {
    typealias PackageResult = PackageController.PackageResult

    @Test func init_no_packageName() async throws {
        // Tests behaviour when we're lacking data
        try await withSPIApp { app in
            // setup package without package name
            let pkg = try await savePackage(on: app.db, "1".url)
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
                                                         swift6Readiness: nil,
                                                         forkedFromInfo: nil,
                                                         customCollections: [])

            // validate
            #expect(m != nil)
            #expect(m?.title == "bar")
        }
    }

    @Test func init_packageIdentity() async throws {
        try await withSPIApp { app in
            let pkg = try await savePackage(on: app.db, URL(string: "https://github.com/foo/swift-bar.git")!)
            try await Repository(package: pkg, name: "bar", owner: "foo").save(on: app.db)
            let version = try App.Version(package: pkg, latest: .defaultBranch, packageName: nil, reference: .branch("main"))
            try await version.save(on: app.db)
            let packageResult = try await PackageResult.query(on: app.db, owner: "foo", repository: "bar")

            // MUT
            let model = try #require(API.PackageController.GetRoute.Model(result: packageResult,
                                                                          history: nil,
                                                                          products: [],
                                                                          targets: [],
                                                                          swiftVersionBuildInfo: nil,
                                                                          platformBuildInfo: nil,
                                                                          weightedKeywords: [],
                                                                          swift6Readiness: nil,
                                                                          forkedFromInfo: nil,
                                                                          customCollections: []))

            // validate
            #expect(model.packageIdentity == "swift-bar")
        }
    }

    @Test func init_generated_documentation() async throws {
        try await withSPIApp { app in
            let pkg = try await savePackage(on: app.db, "1".url)
            try await Repository(package: pkg, name: "bar", owner: "foo").save(on: app.db)
            let version = try App.Version(package: pkg, latest: .defaultBranch, packageName: nil, reference: .branch("main"))
            version.docArchives = [.init(name: "archive1", title: "Archive One")]
            try await version.save(on: app.db)
            let packageResult = try await PackageResult.query(on: app.db, owner: "foo", repository: "bar")

            // MUT
            let model = try #require(API.PackageController.GetRoute.Model(result: packageResult,
                                                                          history: nil,
                                                                          products: [],
                                                                          targets: [],
                                                                          swiftVersionBuildInfo: nil,
                                                                          platformBuildInfo: nil,
                                                                          weightedKeywords: [],
                                                                          swift6Readiness: nil,
                                                                          forkedFromInfo: nil,
                                                                          customCollections: []))

            // validate
            #expect(model.documentationTarget == .internal(docVersion: .reference("main"), archive: "archive1"))
        }
    }

    @Test func init_external_documentation() async throws {
        try await withSPIApp { app in
            let pkg = try await savePackage(on: app.db, "1".url)
            try await Repository(package: pkg, name: "bar", owner: "foo").save(on: app.db)
            let version = try App.Version(package: pkg, latest: .defaultBranch, packageName: nil, reference: .branch("main"))
            version.spiManifest = try .init(yml: """
        version: 1
        external_links:
            documentation: "https://example.com/package/documentation"
        """)
            try await version.save(on: app.db)
            let packageResult = try await PackageResult.query(on: app.db, owner: "foo", repository: "bar")

            // MUT
            let model = try #require(API.PackageController.GetRoute.Model(result: packageResult,
                                                                          history: nil,
                                                                          products: [],
                                                                          targets: [],
                                                                          swiftVersionBuildInfo: nil,
                                                                          platformBuildInfo: nil,
                                                                          weightedKeywords: [],
                                                                          swift6Readiness: nil,
                                                                          forkedFromInfo: nil,
                                                                          customCollections: []))

            // validate
            #expect(model.documentationTarget == .external(url: "https://example.com/package/documentation"))
        }
    }

    @Test func ForkedFromInfo_query() async throws {
        try await withSPIApp { app in
            let originalPkg = try await savePackage(on: app.db, id: .id0, "https://github.com/original/original")
            try await Repository(package: originalPkg,
                                 name: "original",
                                 owner: "original",
                                 ownerName: "OriginalOwner").save(on: app.db)
            try await App.Version(package: originalPkg, latest: .defaultBranch, packageName: "OriginalPkg", reference: .branch("main"))
                .save(on: app.db)

            // MUT
            let forkedFrom = await API.PackageController.GetRoute.Model.ForkedFromInfo.query(on: app.db, packageId: .id0, fallbackURL: "https://github.com/original/original.git")

            // validate
            #expect(forkedFrom == .fromSPI(originalOwner: "original",
                                           originalOwnerName: "OriginalOwner",
                                           originalRepo: "original",
                                           originalPackageName: "OriginalPkg"))
        }
    }

    @Test func ForkedFromInfo_query_fallback() async throws {
        // when the package can't be found resort to fallback URL
        try await withSPIApp { app in
            // MUT
            let forkedFrom = await API.PackageController.GetRoute.Model.ForkedFromInfo.query(on: app.db, packageId: .id0, fallbackURL: "https://github.com/original/original.git")

            // validate
            #expect(forkedFrom == .fromGitHub(url: "https://github.com/original/original.git"))
        }
    }

    @Test func gitHubOwnerUrl() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.repositoryOwner = "owner"
        #expect(model.gitHubOwnerUrl == "https://github.com/owner")
    }

    @Test func gitHubRepositoryUrl() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.repositoryOwner = "owner"
        model.repositoryName = "repository"
        #expect(model.gitHubRepositoryUrl == "https://github.com/owner/repository")
    }

    func history() throws {
        withDependencies {
            $0.date.now = .t0
        } operation: {
            var model = API.PackageController.GetRoute.Model.mock
            model.history = .init(
                createdAt: Calendar.current.date(byAdding: .month, value: -7, to: .t0)!,
                commitCount: 12,
                commitCountURL: "https://example.com/commits.html",
                releaseCount: 2,
                releaseCountURL: "https://example.com/releases.html"
            )

            let renderedHistory = model.historyListItem().render(indentedBy: .spaces(2))
            assertSnapshot(of: renderedHistory, as: .lines)
        }
    }

    @Test func forked_from_github() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.forkedFromInfo = .fromGitHub(url: "https://github.com/owner/repository.git")
        let renderedForkedFrom = model.forkedListItem().render(indentedBy: .spaces(2))
        assertSnapshot(of: renderedForkedFrom, as: .lines)
    }

    @Test func forked_from_spi_same_package_name() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.forkedFromInfo = .fromSPI(
            originalOwner: "owner",
            originalOwnerName: "OriginalOwner",
            originalRepo: "repo",
            originalPackageName: "Test"
        )
        let renderedForkedFrom = model.forkedListItem().render(indentedBy: .spaces(2))
        assertSnapshot(of: renderedForkedFrom, as: .lines)
    }

    @Test func forked_from_spi_different_package_name() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.forkedFromInfo = .fromSPI(
            originalOwner: "owner",
            originalOwnerName: "OriginalOwner",
            originalRepo: "repo",
            originalPackageName: "Different"
        )
        let renderedForkedFrom = model.forkedListItem().render(indentedBy: .spaces(2))
        assertSnapshot(of: renderedForkedFrom, as: .lines)
    }

    @Test func binary_targets() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.hasBinaryTargets = true
        model.licenseUrl = "<license-url-here>"

        let renderedBinaryOnly = model.binaryTargetsItem().render(indentedBy: .spaces(2))
        assertSnapshot(of: renderedBinaryOnly, as: .lines)
    }

    @Test func binary_targets_no_license() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.hasBinaryTargets = true
        model.licenseUrl = nil

        let renderedBinaryOnly = model.binaryTargetsItem().render(indentedBy: .spaces(2))
        assertSnapshot(of: renderedBinaryOnly, as: .lines)
    }

    @Test func history_archived_package() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.history = .init(
            createdAt: Calendar.current.date(byAdding: .month, value: -7, to: Date.now)!,
            commitCount: 12,
            commitCountURL: "https://example.com/commits.html",
            releaseCount: 2,
            releaseCountURL: "https://example.com/releases.html"
        )
        model.isArchived = true

        let renderedHistory = model.historyListItem().render(indentedBy: .spaces(2))
        assertSnapshot(of: renderedHistory, as: .lines)
    }

    @Test func archived_warning_line_for_active_package() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.isArchived = false

        let renderedHistory = model.archivedListItem().render(indentedBy: .spaces(2))
        assertSnapshot(of: renderedHistory, as: .lines)
    }

    @Test func archived_warning_line_for_archived_package() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.isArchived = true

        let renderedHistory = model.archivedListItem().render(indentedBy: .spaces(2))
        assertSnapshot(of: renderedHistory, as: .lines)
    }

    func activity_variants__missing_open_issue() throws {
        withDependencies {
            $0.date.now = .t0
        } operation: {
            var model = API.PackageController.GetRoute.Model.mock
            model.activity?.openIssuesURL = nil

            let renderedActivity = model.activityListItem().render(indentedBy: .spaces(2))
            assertSnapshot(of: renderedActivity, as: .lines)
        }
    }

    func activity_variants__missing_open_PRs() throws {
        withDependencies {
            $0.date.now = .t0
        } operation: {
            var model = API.PackageController.GetRoute.Model.mock
            model.activity?.openPullRequestsURL = nil

            let renderedActivity = model.activityListItem().render(indentedBy: .spaces(2))
            assertSnapshot(of: renderedActivity, as: .lines)
        }
    }

    func activity_variants__missing_open_issues_and_PRs() throws {
        withDependencies {
            $0.date.now = .t0
        } operation: {
            var model = API.PackageController.GetRoute.Model.mock
            model.activity?.openIssuesURL = nil
            model.activity?.openPullRequestsURL = nil

            let renderedActivity = model.activityListItem().render(indentedBy: .spaces(2))
            assertSnapshot(of: renderedActivity, as: .lines)
        }
    }

    func activity_variants__missing_last_closed_issue() throws {
        withDependencies {
            $0.date.now = .t0
        } operation: {
            var model = API.PackageController.GetRoute.Model.mock
            model.activity?.lastIssueClosedAt = nil

            let renderedActivity = model.activityListItem().render(indentedBy: .spaces(2))
            assertSnapshot(of: renderedActivity, as: .lines)
        }
    }

    func activity_variants__missing_last_closed_PR() throws {
        withDependencies {
            $0.date.now = .t0
        } operation: {
            var model = API.PackageController.GetRoute.Model.mock
            model.activity?.lastPullRequestClosedAt = nil

            let renderedActivity = model.activityListItem().render(indentedBy: .spaces(2))
            assertSnapshot(of: renderedActivity, as: .lines)
        }
    }

    @Test func activity_variants__missing_last_closed_issue_and_PR() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.activity?.lastIssueClosedAt = nil
        model.activity?.lastPullRequestClosedAt = nil

        let renderedActivity = model.activityListItem().render(indentedBy: .spaces(2))
        assertSnapshot(of: renderedActivity, as: .lines)
    }

    @Test func activity_variants__missing_everything() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.activity?.openIssuesURL = nil
        model.activity?.openPullRequestsURL = nil
        model.activity?.lastIssueClosedAt = nil
        model.activity?.lastPullRequestClosedAt = nil

        #expect(model.activityListItem().render() == "")
    }

    @Test func dependenciesPhrase_with_dependencies() throws {
        let model = API.PackageController.GetRoute.Model.mock
        #expect(model.dependenciesPhrase() == "This package depends on 2 other packages.")
    }

    @Test func dependenciesPhrase_no_dependencies() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.dependencies = []
        #expect(model.dependenciesPhrase() == "This package has no package dependencies.")
    }

    @Test func dependenciesPhrase_nil_dependencies() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.dependencies = nil
        #expect(model.dependenciesPhrase() == nil)
    }

    @Test func stars_formatting() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.stars = 999
        #expect(model.starsListItem().render() == "<li class=\"stars\">999 stars</li>")
        model.stars = 1_000
        #expect(model.starsListItem().render() == "<li class=\"stars\">1,000 stars</li>")
        model.stars = 1_000_000
        #expect(model.starsListItem().render() == "<li class=\"stars\">1,000,000 stars</li>")
    }

    @Test func productTypeListItem_formatting() throws {
        var model = API.PackageController.GetRoute.Model.mock

        // Libraries and plurality
        model.products = []
        #expect(model.productTypeListItem(.library).render() == "<li class=\"libraries\">No libraries</li>")

        model.products = [.init(name: "lib1", type: .library)]
        #expect(model.productTypeListItem(.library).render() == "<li class=\"libraries\">1 library</li>")

        model.products = [.init(name: "lib1", type: .library), .init(name: "lib2", type: .library)]
        #expect(model.productTypeListItem(.library).render() == "<li class=\"libraries\">2 libraries</li>")

        // Executables and Plugins
        model.products = [.init(name: "exe1", type: .executable), .init(name: "exe2", type: .executable)]
        #expect(model.productTypeListItem(.executable).render() == "<li class=\"executables\">2 executables</li>")

        model.products = [.init(name: "plg1", type: .plugin), .init(name: "plg2", type: .plugin)]
        #expect(model.productTypeListItem(.plugin).render() == "<li class=\"plugins\">2 plugins</li>")
    }

    @Test func targetTypeListItem_formatting() throws {
        var model = API.PackageController.GetRoute.Model.mock

        // Macros
        model.targets = []
        #expect(model.targetTypeListItem(.macro).render() == "<li class=\"macros\">No macros</li>")

        model.targets = [.init(name: "macro1", type: .macro)]
        #expect(model.targetTypeListItem(.macro).render() == "<li class=\"macros\">1 macro</li>")

        model.targets = [.init(name: "macro1", type: .macro), .init(name: "macro2", type: .macro)]
        #expect(model.targetTypeListItem(.macro).render() == "<li class=\"macros\">2 macros</li>")
    }

    @Test func authorMetadata() throws {
        var model = API.PackageController.GetRoute.Model.mock

        model.authors = API.PackageController.GetRoute.Model.AuthorMetadata .fromGitRepository(PackageAuthors(authors: [
            Author(name: "Author One"),
            Author(name: "Author Two")
        ], numberOfContributors: 5))
        #expect(model.authorsListItem().render() == "<li class=\"authors\">Written by Author One, Author Two, and 5 other contributors.</li>")

        model.authors = API.PackageController.GetRoute.Model.AuthorMetadata
            .fromSPIManifest("By Author One, Author Two, and more!")
        #expect(model.authorsListItem().render() == "<li class=\"authors\">By Author One, Author Two, and more!</li>")
    }

    @Test func forkedFrom_github_formatting() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.forkedFromInfo = .fromGitHub(url: "https://github.com/owner/repository.git")
        let renderedForkedFrom = model.forkedListItem().render()
        #expect(renderedForkedFrom == "<li class=\"forked\">Forked from <a href=\"https://github.com/owner/repository.git\">owner/repository</a>.</li>")
    }

    @Test func forkedFrom_spi_same_package_name_formatting() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.forkedFromInfo = .fromSPI(
            originalOwner: "owner",
            originalOwnerName: "OriginalOwner",
            originalRepo: "repo",
            originalPackageName: "Test"
        )
        let url = SiteURL.package(.value("owner"), .value("repo"), nil).relativeURL()
        let ownerUrl = model.forkedFromInfo?.ownerURL ?? ""
        let renderedForkedFrom = model.forkedListItem().render()
        #expect(renderedForkedFrom == "<li class=\"forked\">Forked from <a href=\"\(url)\">Test</a> by <a href=\"\(ownerUrl)\">OriginalOwner</a>.</li>")
    }

    @Test func forkedFrom_spi_different_package_name_formatting() throws {
        var model = API.PackageController.GetRoute.Model.mock
        model.forkedFromInfo = .fromSPI(
            originalOwner: "owner",
            originalOwnerName: "OriginalOwner",
            originalRepo: "repo",
            originalPackageName: "Different"
        )
        let url = SiteURL.package(.value("owner"), .value("repo"), nil).relativeURL()
        let ownerUrl = model.forkedFromInfo?.ownerURL ?? ""
        let renderedForkedFrom = model.forkedListItem().render()
        #expect(renderedForkedFrom == "<li class=\"forked\">Forked from <a href=\"\(url)\">Different</a> by <a href=\"\(ownerUrl)\">OriginalOwner</a>.</li>")
    }

    @Test func BuildInfo_init() throws {
        // ensure nil propagation when all versions' values are nil
        // (the generic type is irrelevant, we're just using Int for simplicity)
        #expect(BuildInfo<Int>.init(stable: nil, beta: nil, latest: nil) == nil)
        #expect(BuildInfo<Int>.init(stable: .init(referenceName: "foo", results: 1),
                                            beta: nil,
                                            latest: nil) != nil)
    }

    @Test func BuildInfo_SwiftVersion_compatibility() throws {
        typealias Results = CompatibilityMatrix.SwiftVersionCompatibility

        do {
            let info = BuildInfo(stable: .some(.init(referenceName: "1.2.3",
                                                     results: Results(results: [.v1: .compatible,
                                                                                .v2: .incompatible,
                                                                                .v3: .unknown,
                                                                                .v4: .compatible]))),
                                 beta: nil,
                                 latest: nil)
            #expect(info?.compatibility == [.v1, .v4])
        }
        do {
            let info = BuildInfo(stable: .some(.init(referenceName: "1.2.3",
                                                     results: Results(results: [.v1: .compatible,
                                                                                .v2: .incompatible,
                                                                                .v3: .unknown,
                                                                                .v4: .compatible]))),
                                 beta: .some(.init(referenceName: "1.2.3-b1",
                                                   results: Results(results: [.v1: .incompatible,
                                                                              .v2: .incompatible,
                                                                              .v3: .compatible,
                                                                              .v4: .unknown]))),
                                 latest: nil)
            #expect(info?.compatibility == [.v1, .v3, .v4])
        }
    }

    @Test func BuildInfo_Platform_compatibility() throws {
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
            #expect(info?.compatibility == [.iOS, .watchOS])
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
            #expect(info?.compatibility == [.iOS, .macOS, .watchOS])
        }
    }

    @Test func groupBuildInfo() async throws {
        try await withSPIApp { app in
            let result1: BuildResults = .init(results: [.v1: .compatible,
                                                        .v2: .compatible,
                                                        .v3: .compatible,
                                                        .v4: .compatible])
            let result2: BuildResults = .init(results: [.v1: .compatible,
                                                        .v2: .incompatible,
                                                        .v3: .incompatible,
                                                        .v4: .incompatible])
            let result3: BuildResults = .init(results: [.v1: .unknown,
                                                        .v2: .unknown,
                                                        .v3: .unknown,
                                                        .v4: .unknown])
            do {  // three distinct groups
                let buildInfo: BuildInfo = .init(stable: .init(referenceName: "1.2.3", results: result1),
                                                 beta: .init(referenceName: "2.0.0-b1", results: result2),
                                                 latest: .init(referenceName: "main", results: result3))!

                // MUT
                let res = API.PackageController.GetRoute.Model.groupBuildInfo(buildInfo)

                // validate
                #expect(res == [
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
                #expect(res == [
                    .init(references: [.init(name: "1.2.3", kind: .release),
                                       .init(name: "main", kind: .defaultBranch)], results: result1),
                    .init(references: [.init(name: "2.0.0-b1", kind: .preRelease)], results: result2),
                ])
            }
        }
    }

    @Test func languagePlatformInfo() async throws {
        try await withSPIApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "1")
            try await Repository(package: pkg,
                                 defaultBranch: "default",
                                 name: "bar",
                                 owner: "foo").save(on: app.db)
            try await [
                try App.Version(package: pkg, reference: .branch("branch")),
                try App.Version(package: pkg,
                                commitDate: Date.now.adding(days: -1),
                                latest: .defaultBranch,
                                reference: .branch("default"),
                                supportedPlatforms: [.macos("10.15"), .ios("13")],
                                swiftVersions: ["5.2", "5.3"].asSwiftVersions),
                try App.Version(package: pkg, reference: .tag(.init(1, 2, 3))),
                try App.Version(package: pkg,
                                commitDate: Date.now.adding(days: -3),
                                latest: .release,
                                reference: .tag(.init(2, 1, 0)),
                                supportedPlatforms: [.macos("10.13"), .ios("10")],
                                swiftVersions: ["4", "5"].asSwiftVersions),
                try App.Version(package: pkg,
                                commitDate: Date.now.adding(days: -2),
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
            #expect(lpInfo.stable?.link == .init(label: "2.1.0",
                                                 url: "1/releases/tag/2.1.0"))
            #expect(lpInfo.stable?.swiftVersions == ["4", "5"])
            #expect(lpInfo.stable?.platforms == [.macos("10.13"), .ios("10")])

            #expect(lpInfo.beta?.link == .init(label: "3.0.0-beta",
                                               url: "1/releases/tag/3.0.0-beta"))
            #expect(lpInfo.beta?.swiftVersions == ["5", "5.2"])
            #expect(lpInfo.beta?.platforms == [.macos("10.14"), .ios("13")])

            #expect(lpInfo.latest?.link == .init(label: "default", url: "1"))
            #expect(lpInfo.latest?.swiftVersions == ["5.2", "5.3"])
            #expect(lpInfo.latest?.platforms == [.macos("10.15"), .ios("13")])
        }
    }

    @Test func packageDependencyCodeSnippet() {
        let releaseRefs: [App.Version.Kind: App.Reference] = [
            .release: .tag(5, 5, 0),
            .preRelease: .tag(6, 0, 0, "b1"),
            .defaultBranch: .branch("main")
        ]
        #expect(
            API.PackageController.GetRoute.Model.packageDependencyCodeSnippet(
                for: .preRelease,
                releaseReferences: releaseRefs,
                packageURL: "https://github.com/Alamofire/Alamofire.git"
            ) == .init(label: "6.0.0-b1",
                  url: ".package(url: &quot;https://github.com/Alamofire/Alamofire.git&quot;, from: &quot;6.0.0-b1&quot;)")
        )
        #expect(
            API.PackageController.GetRoute.Model.packageDependencyCodeSnippet(
                for: .release,
                releaseReferences: releaseRefs,
                packageURL: "https://github.com/Alamofire/Alamofire.git"
            ) == .init(label: "5.5.0",
                  url: ".package(url: &quot;https://github.com/Alamofire/Alamofire.git&quot;, from: &quot;5.5.0&quot;)")
        )
        #expect(
            API.PackageController.GetRoute.Model.packageDependencyCodeSnippet(
                for: .defaultBranch,
                releaseReferences: releaseRefs,
                packageURL: "https://github.com/Alamofire/Alamofire.git"
            ) == .init(label: "main",
                  url: ".package(url: &quot;https://github.com/Alamofire/Alamofire.git&quot;, branch: &quot;main&quot;)")
        )
    }

    @Test func Swift6Readiness_dataRaceSafety() {
        #expect(Swift6Readiness(errorCounts: [:]).dataRaceSafety == .unknown)
        #expect(Swift6Readiness(errorCounts: [.iOS: 1]).dataRaceSafety == .unsafe)
        #expect(Swift6Readiness(errorCounts: [.iOS: 1, .linux: 0]).dataRaceSafety == .safe)
    }

    @Test func Swift6Readiness_title() {
        #expect(Swift6Readiness(errorCounts: [:]).title == "No data available")
        #expect(Swift6Readiness(errorCounts: [.iOS: 1]).title == """
            Error counts:
            iOS: 1
            """)
        #expect(Swift6Readiness(errorCounts: [.iOS: 1, .macosSpm: 0]).title == """
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
