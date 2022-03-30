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

@testable import App

import XCTVapor
import SnapshotTesting


class PackageShowModelTests: SnapshotTestCase {
    typealias PackageResult = PackageController.PackageResult

    func test_init_no_packageName() throws {
        // Tests behaviour when we're lacking data
        // setup package without package name
        let pkg = try savePackage(on: app.db, "1".url)
        try Repository(package: pkg, name: "bar", owner: "foo").save(on: app.db).wait()
        let version = try App.Version(package: pkg,
                                      latest: .defaultBranch,
                                      packageName: nil,
                                      reference: .branch("main"))
        try version.save(on: app.db).wait()
        let pr = try PackageResult.query(on: app.db, owner: "foo", repository: "bar").wait()

        // MUT
        let m = PackageShow.Model(result: pr,
                                  history: nil,
                                  productCounts: .mock,
                                  swiftVersionBuildInfo: nil,
                                  platformBuildInfo: nil)
        
        // validate
        XCTAssertNotNil(m)
        XCTAssertEqual(m?.title, "bar")
    }

    func test_history() throws {
        var model = PackageShow.Model.mock
        model.history = .init(
            since: "7 months",
            commitCount: .init(label: "12 commits", url: "https://example.com/commits.html"),
            releaseCount: .init(label: "2 releases", url: "https://example.com/releases.html")
        )

        let renderedHistory = model.historyListItem().render(indentedBy: .spaces(2))
        assertSnapshot(matching: renderedHistory, as: .lines)
    }

    func test_history_archived_package() throws {
        var model = PackageShow.Model.mock
        model.history = .init(
            since: "7 months",
            commitCount: .init(label: "12 commits", url: "https://example.com/commits.html"),
            releaseCount: .init(label: "2 releases", url: "https://example.com/releases.html")
        )
        model.isArchived = true

        let renderedHistory = model.historyListItem().render(indentedBy: .spaces(2))
        assertSnapshot(matching: renderedHistory, as: .lines)
    }
    
    func test_archived_warning_line_for_active_package() throws {
        var model = PackageShow.Model.mock
        model.isArchived = false
        
        let renderedHistory = model.archivedListItem().render(indentedBy: .spaces(2))
        assertSnapshot(matching: renderedHistory, as: .lines)
    }
    
    func test_archived_warning_line_for_archived_package() throws {
        var model = PackageShow.Model.mock
        model.isArchived = true

        let renderedHistory = model.archivedListItem().render(indentedBy: .spaces(2))
        assertSnapshot(matching: renderedHistory, as: .lines)
    }

    func test_activity_variants__missing_open_issue() throws {
        var model = PackageShow.Model.mock
        model.activity?.openIssues = nil

        let renderedActivity = model.activityListItem().render(indentedBy: .spaces(2))
        assertSnapshot(matching: renderedActivity, as: .lines)
    }
    
    func test_activity_variants__missing_open_PRs() throws {
        var model = PackageShow.Model.mock
        model.activity?.openPullRequests = nil

        let renderedActivity = model.activityListItem().render(indentedBy: .spaces(2))
        assertSnapshot(matching: renderedActivity, as: .lines)
    }
    
    func test_activity_variants__missing_open_issues_and_PRs() throws {
        var model = PackageShow.Model.mock
        model.activity?.openIssues = nil
        model.activity?.openPullRequests = nil

        let renderedActivity = model.activityListItem().render(indentedBy: .spaces(2))
        assertSnapshot(matching: renderedActivity, as: .lines)
    }
    
    func test_activity_variants__missing_last_closed_issue() throws {
        var model = PackageShow.Model.mock
        model.activity?.lastIssueClosedAt = nil

        let renderedActivity = model.activityListItem().render(indentedBy: .spaces(2))
        assertSnapshot(matching: renderedActivity, as: .lines)
    }
    
    func test_activity_variants__missing_last_closed_PR() throws {
        var model = PackageShow.Model.mock
        model.activity?.lastPullRequestClosedAt = nil

        let renderedActivity = model.activityListItem().render(indentedBy: .spaces(2))
        assertSnapshot(matching: renderedActivity, as: .lines)
    }
    
    func test_activity_variants__missing_last_closed_issue_and_PR() throws {
        var model = PackageShow.Model.mock
        model.activity?.lastIssueClosedAt = nil
        model.activity?.lastPullRequestClosedAt = nil

        let renderedActivity = model.activityListItem().render(indentedBy: .spaces(2))
        assertSnapshot(matching: renderedActivity, as: .lines)
    }
    
    func test_activity_variants__missing_everything() throws {
        var model = PackageShow.Model.mock
        model.activity?.openIssues = nil
        model.activity?.openPullRequests = nil
        model.activity?.lastIssueClosedAt = nil
        model.activity?.lastPullRequestClosedAt = nil

        XCTAssertEqual(model.activityListItem().render(), "")
    }

    func test_dependenciesPhrase_with_dependencies() throws {
        let model = PackageShow.Model.mock
        XCTAssertEqual(model.dependenciesPhrase(), "This package depends on 2 other packages.")
    }

    func test_dependenciesPhrase_no_dependencies() throws {
        var model = PackageShow.Model.mock
        model.dependencies = []
        XCTAssertEqual(model.dependenciesPhrase(), "This package has no package dependencies.")
    }

    func test_dependenciesPhrase_nil_dependencies() throws {
        var model = PackageShow.Model.mock
        model.dependencies = nil
        XCTAssertEqual(model.dependenciesPhrase(), nil)
    }

    func test_stars_formatting() throws {
        var model = PackageShow.Model.mock
        model.stars = 999
        XCTAssertEqual(model.starsListItem().render(), "<li class=\"stars\">999 stars</li>")
        model.stars = 1_000
        XCTAssertEqual(model.starsListItem().render(), "<li class=\"stars\">1,000 stars</li>")
        model.stars = 1_000_000
        XCTAssertEqual(model.starsListItem().render(), "<li class=\"stars\">1,000,000 stars</li>")
    }

    func test_num_libraries_formatting() throws {
        var model = PackageShow.Model.mock
        model.productCounts?.libraries = 0
        XCTAssertEqual(model.librariesListItem().render(), "<li class=\"libraries\">No libraries</li>")
        model.productCounts?.libraries = 1
        XCTAssertEqual(model.librariesListItem().render(), "<li class=\"libraries\">1 library</li>")
        model.productCounts?.libraries = 2
        XCTAssertEqual(model.librariesListItem().render(), "<li class=\"libraries\">2 libraries</li>")
    }
    
    func test_num_executables_formatting() throws {
        var model = PackageShow.Model.mock
        model.productCounts?.executables = 0
        XCTAssertEqual(model.executablesListItem().render(), "<li class=\"executables\">No executables</li>")
        model.productCounts?.executables = 1
        XCTAssertEqual(model.executablesListItem().render(), "<li class=\"executables\">1 executable</li>")
        model.productCounts?.executables = 2
        XCTAssertEqual(model.executablesListItem().render(), "<li class=\"executables\">2 executables</li>")
    }

    func test_BuildInfo_init() throws {
        // ensure nil propagation when all versions' values are nil
        // (the generic type is irrelevant, we're just using Int for simplicity)
        XCTAssertNil(BuildInfo<Int>.init(stable: nil, beta: nil, latest: nil))
        XCTAssertNotNil(BuildInfo<Int>.init(stable: .init(referenceName: "foo", results: 1),
                                            beta: nil,
                                            latest: nil))
    }

    func test_groupBuildInfo() throws {
        let result1: BuildResults = .init(status5_1: .compatible,
                                          status5_2: .compatible,
                                          status5_3: .compatible,
                                          status5_4: .compatible,
                                          status5_5: .compatible,
                                          status5_6: .compatible)
        let result2: BuildResults = .init(status5_1: .incompatible,
                                          status5_2: .incompatible,
                                          status5_3: .incompatible,
                                          status5_4: .incompatible,
                                          status5_5: .incompatible,
                                          status5_6: .incompatible)
        let result3: BuildResults = .init(status5_1: .unknown,
                                          status5_2: .unknown,
                                          status5_3: .unknown,
                                          status5_4: .unknown,
                                          status5_5: .unknown,
                                          status5_6: .unknown)
        do {  // three distinct groups
            let buildInfo: BuildInfo = .init(stable: .init(referenceName: "1.2.3",
                                                           results: result1),
                                             beta: .init(referenceName: "2.0.0-b1",
                                                         results: result2),
                                             latest: .init(referenceName: "main",
                                                           results: result3))!
            
            // MUT
            let res = PackageShow.Model.groupBuildInfo(buildInfo)
            
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
            let res = PackageShow.Model.groupBuildInfo(buildInfo)
            
            // validate
            XCTAssertEqual(res, [
                .init(references: [.init(name: "1.2.3", kind: .release),
                                   .init(name: "main", kind: .defaultBranch)], results: result1),
                .init(references: [.init(name: "2.0.0-b1", kind: .preRelease)], results: result2),
            ])
        }
    }

    func test_languagePlatformInfo() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg,
                       defaultBranch: "default",
                       name: "bar",
                       owner: "foo").save(on: app.db).wait()
        try [
            try App.Version(package: pkg, reference: .branch("branch")),
            try App.Version(package: pkg,
                            commitDate: daysAgo(1),
                            latest: .defaultBranch,
                            reference: .branch("default"),
                            supportedPlatforms: [.macos("10.15"), .ios("13")],
                            swiftVersions: ["5.2", "5.3"].asSwiftVersions),
            try App.Version(package: pkg, reference: .tag(.init(1, 2, 3))),
            try App.Version(package: pkg,
                            commitDate: daysAgo(3),
                            latest: .release,
                            reference: .tag(.init(2, 1, 0)),
                            supportedPlatforms: [.macos("10.13"), .ios("10")],
                            swiftVersions: ["4", "5"].asSwiftVersions),
            try App.Version(package: pkg,
                            commitDate: daysAgo(2),
                            latest: .preRelease,
                            reference: .tag(.init(3, 0, 0, "beta")),
                            supportedPlatforms: [.macos("10.14"), .ios("13")],
                            swiftVersions: ["5", "5.2"].asSwiftVersions),
        ].save(on: app.db).wait()
        let pr = try PackageResult.query(on: app.db,
                                         owner: "foo",
                                         repository: "bar").wait()

        // MUT
        let lpInfo = PackageShow.Model
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
        XCTAssertEqual(
            PackageShow.Model.packageDependencyCodeSnippet(
                ref: "6.0.0-b1",
                url: "https://github.com/Alamofire/Alamofire/releases/tag/6.0.0-b1"),
            ".package(url: &quot;https://github.com/Alamofire/Alamofire.git&quot;, from: &quot;6.0.0-b1&quot;)")
        XCTAssertEqual(
            PackageShow.Model.packageDependencyCodeSnippet(
                ref: "5.5.0",
                url: "https://github.com/Alamofire/Alamofire/releases/tag/5.5.0"),
            ".package(url: &quot;https://github.com/Alamofire/Alamofire.git&quot;, from: &quot;5.5.0&quot;)")
        XCTAssertEqual(
            PackageShow.Model.packageDependencyCodeSnippet(
                ref: "master",
                url: "https://github.com/Alamofire/Alamofire.git"),
            ".package(url: &quot;https://github.com/Alamofire/Alamofire.git&quot;, branch: &quot;master&quot;)")
    }

}


// local typealiases / references to make tests more readable
fileprivate typealias Version = PackageShow.Model.Version
fileprivate typealias BuildInfo = PackageShow.Model.BuildInfo
fileprivate typealias BuildResults = PackageShow.Model.SwiftVersionResults
fileprivate typealias BuildStatusRow = PackageShow.Model.BuildStatusRow


private extension PackageShow.Model.ProductCounts {
    static var mock: Self {
        .init(libraries: 0, executables: 0)
    }
}
