@testable import App

import XCTVapor
import SnapshotTesting


class PackageShowModelTests: SnapshotTestCase {

    func test_init_no_title() throws {
        // Tests behaviour when we're lacking data
        // setup package without package name
        var pkg = try savePackage(on: app.db, "1".url)
        try Repository(package: pkg,
                       summary: "summary",
                       defaultBranch: "main",
                       license: .mit,
                       name: "bar",
                       owner: "foo",
                       stars: 17,
                       forks: 42).save(on: app.db).wait()
        let version = try App.Version(package: pkg,
                                      packageName: nil,
                                      reference: .branch("main"))
        try version.save(on: app.db).wait()
        try Product(version: version,
                    type: .library, name: "lib 1").save(on: app.db).wait()
        // reload via query to ensure relationships are loaded
        pkg = try Package.query(on: app.db, owner: "foo", repository: "bar").wait()
        
        // MUT
        let m = PackageShow.Model(package: pkg)
        
        // validate
        XCTAssertNil(m)
    }
    
    func test_query_builds() throws {
        // Ensure the builds relationship is loaded
        // setup
        var pkg = try savePackage(on: app.db, "1".url)
        try Repository(package: pkg,
                       summary: "summary",
                       defaultBranch: "main",
                       license: .mit,
                       name: "bar",
                       owner: "foo",
                       stars: 17,
                       forks: 42).save(on: app.db).wait()
        let version = try App.Version(package: pkg,
                                      packageName: "test package",
                                      reference: .branch("main"))
        try version.save(on: app.db).wait()
        try Build(version: version,
                  platform: .macosXcodebuild,
                  status: .ok,
                  swiftVersion: .init(5, 2, 2))
            .save(on: app.db)
            .wait()
        // re-load repository relationship (required for updateLatestVersions)
        try pkg.$repositories.load(on: app.db).wait()
        // update versions
        _ = try updateLatestVersions(on: app.db, package: pkg).wait()
        // reload via query to ensure pkg is in the same state it would normally be
        pkg = try Package.query(on: app.db, owner: "foo", repository: "bar").wait()

        // MUT
        let m = PackageShow.Model(package: pkg)
        
        // validate
        XCTAssertNotNil(m?.swiftVersionBuildInfo?.latest)
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
        model.products?.libraries = 0
        XCTAssertEqual(model.librariesListItem().render(), "<li class=\"libraries\">No libraries</li>")
        model.products?.libraries = 1
        XCTAssertEqual(model.librariesListItem().render(), "<li class=\"libraries\">1 library</li>")
        model.products?.libraries = 2
        XCTAssertEqual(model.librariesListItem().render(), "<li class=\"libraries\">2 libraries</li>")
    }
    
    func test_num_executables_formatting() throws {
        var model = PackageShow.Model.mock
        model.products?.executables = 0
        XCTAssertEqual(model.executablesListItem().render(), "<li class=\"executables\">No executables</li>")
        model.products?.executables = 1
        XCTAssertEqual(model.executablesListItem().render(), "<li class=\"executables\">1 executable</li>")
        model.products?.executables = 2
        XCTAssertEqual(model.executablesListItem().render(), "<li class=\"executables\">2 executables</li>")
    }

    func test_groupBuildInfo() throws {
        let result1: BuildResults = .init(status4_2: .compatible,
                                          status5_0: .compatible,
                                          status5_1: .compatible,
                                          status5_2: .compatible,
                                          status5_3: .compatible)
        let result2: BuildResults = .init(status4_2: .incompatible,
                                          status5_0: .incompatible,
                                          status5_1: .incompatible,
                                          status5_2: .incompatible,
                                          status5_3: .incompatible)
        let result3: BuildResults = .init(status4_2: .unknown,
                                          status5_0: .unknown,
                                          status5_1: .unknown,
                                          status5_2: .unknown,
                                          status5_3: .unknown)
        do {  // three distinct groups
            let buildInfo: BuildInfo = .init(stable: .init(referenceName: "1.2.3",
                                                           results: result1),
                                             beta: .init(referenceName: "2.0.0-b1",
                                                         results: result2),
                                             latest: .init(referenceName: "main",
                                                           results: result3))
            
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
                                                           results: result1))
            
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

}


// local typealiases / references to make tests more readable
fileprivate typealias Version = PackageShow.Model.Version
fileprivate typealias BuildInfo = PackageShow.Model.BuildInfo
fileprivate typealias BuildResults = PackageShow.Model.SwiftVersionResults
fileprivate typealias BuildStatusRow = PackageShow.Model.BuildStatusRow
