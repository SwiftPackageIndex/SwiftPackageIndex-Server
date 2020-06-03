@testable import App

import XCTVapor


class PackageShowModelTests: AppTestCase {

    func test_query_owner_repository() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1".url)
        try Repository(package: pkg,
                       summary: "summary",
                       defaultBranch: "master",
                       license: .mit,
                       name: "bar",
                       owner: "foo",
                       stars: 17,
                       forks: 42).save(on: app.db).wait()
        let version = try App.Version(package: pkg,
                                      reference: .branch("master"),
                                      packageName: "test package")
        try version.save(on: app.db).wait()
        try Product(version: version,
                    type: .library, name: "lib 1").save(on: app.db).wait()

        // MUT
        let m = try PackageShow.Model.query(database: app.db, owner: "foo", repository: "bar").wait()

        // validate
        XCTAssertEqual(m.title, "test package")
    }

    func test_query_owner_repository_case_insensitivity() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1".url)
        try Repository(package: pkg,
                       summary: "summary",
                       defaultBranch: "master",
                       license: .mit,
                       name: "bar",
                       owner: "foo",
                       stars: 17,
                       forks: 42).save(on: app.db).wait()
        let version = try App.Version(package: pkg,
                                      reference: .branch("master"),
                                      packageName: "test package")
        try version.save(on: app.db).wait()
        try Product(version: version,
                    type: .library, name: "lib 1").save(on: app.db).wait()

        // MUT
        let m = try PackageShow.Model.query(database: app.db, owner: "Foo", repository: "bar").wait()

        // validate
        XCTAssertEqual(m.title, "test package")
    }

    func test_query_no_title() throws {
        // Tests behaviour when we're lacking data
        // setup package without package name
        let pkg = try savePackage(on: app.db, "1".url)
        try Repository(package: pkg,
                       summary: "summary",
                       defaultBranch: "master",
                       license: .mit,
                       name: "bar",
                       owner: "foo",
                       stars: 17,
                       forks: 42).save(on: app.db).wait()
        let version = try App.Version(package: pkg,
                                      reference: .branch("master"),
                                      packageName: nil)
        try version.save(on: app.db).wait()
        try Product(version: version,
                    type: .library, name: "lib 1").save(on: app.db).wait()

        // MUT
        XCTAssertThrowsError(try PackageShow.Model.query(database: app.db, owner: "foo", repository: "bar").wait()) {
            let error = try? XCTUnwrap($0 as? Vapor.Abort)
            XCTAssertEqual(error?.identifier, "404")
        }
    }

    func test_lpInfoGroups_by_swiftVersions() throws {
        // Test grouping by swift versions
        let lnk = Link(label: "1", url: "1")
        let v1 = Version(link: lnk, swiftVersions: ["1"], platforms: [.macos("10")])
        let v2 = Version(link: lnk, swiftVersions: ["2"], platforms: [.macos("10")])
        let v3 = Version(link: lnk, swiftVersions: ["3"], platforms: [.macos("10")])

        XCTAssertEqual(lpInfoGroups(.init(stable: v1, beta: v2, latest: v3)),
                       [[\.stable], [\.beta], [\.latest]])
        XCTAssertEqual(lpInfoGroups(.init(stable: v1, beta: v2, latest: v2)),
                       [[\.stable], [\.beta, \.latest]])
        XCTAssertEqual(lpInfoGroups(.init(stable: v1, beta: v1, latest: v2)),
                       [[\.stable, \.beta], [\.latest]])
        XCTAssertEqual(lpInfoGroups(.init(stable: v2, beta: v1, latest: v2)),
                       [[\.stable, \.latest], [\.beta]])
        XCTAssertEqual(lpInfoGroups(.init(stable: v1, beta: v1, latest: v1)),
                       [[\.stable, \.beta, \.latest]])
    }

    func test_lpInfoGroups_by_platforms() throws {
        // Test grouping by platforms
        let lnk = Link(label: "1", url: "1")
        let v1 = Version(link: lnk, swiftVersions: ["1"], platforms: [.macos("10")])
        let v2 = Version(link: lnk, swiftVersions: ["1"], platforms: [.macos("11")])
        let v3 = Version(link: lnk, swiftVersions: ["1"], platforms: [.macos("12")])

        XCTAssertEqual(lpInfoGroups(.init(stable: v1, beta: v2, latest: v3)),
                       [[\.stable], [\.beta], [\.latest]])
        XCTAssertEqual(lpInfoGroups(.init(stable: v1, beta: v2, latest: v2)),
                       [[\.stable], [\.beta, \.latest]])
        XCTAssertEqual(lpInfoGroups(.init(stable: v1, beta: v1, latest: v2)),
                       [[\.stable, \.beta], [\.latest]])
        XCTAssertEqual(lpInfoGroups(.init(stable: v2, beta: v1, latest: v2)),
                       [[\.stable, \.latest], [\.beta]])
        XCTAssertEqual(lpInfoGroups(.init(stable: v1, beta: v1, latest: v1)),
                       [[\.stable, \.beta, \.latest]])
    }

    func test_lpInfoGroups_ignores_link() throws {
        // Test to ensure the link isn't part of the grouping
        let l1 = Link(label: "1", url: "1")
        let l2 = Link(label: "2", url: "2")
        let l3 = Link(label: "3", url: "3")
        let v1 = Version(link: l1, swiftVersions: ["1"], platforms: [.macos("10")])
        let v2 = Version(link: l2, swiftVersions: ["1"], platforms: [.macos("10")])
        let v3 = Version(link: l3, swiftVersions: ["1"], platforms: [.macos("10")])

        XCTAssertEqual(lpInfoGroups(.init(stable: v1, beta: v2, latest: v3)),
                       [[\.stable, \.beta, \.latest]])
    }

    func test_lpInfoSection_nil() throws {
        // Test to ensure lpInfoSection returns nil when there are no swift versions or platforms
        // setup
        let lpInfo = PackageShow.Model.LanguagePlatformInfo(
            stable: .init(link: .init(label: "1", url: "1"), swiftVersions: [], platforms: []),
            beta: nil,
            latest: .init(link: .init(label: "2", url: "2"), swiftVersions: [], platforms: [])
        )

        // MUT
        let res = PackageShow.Model.lpInfoSection(keypaths: [\.stable, \.latest],
                                                  languagePlatforms: lpInfo)

        // validate
        XCTAssertNil(res)
    }

    // Test output of some activity variants without firing up a full snapshot test:
    func test_activity_variants__missing_open_issue() throws {
        var model = PackageShow.Model.mock
        model.activity?.openIssues = nil
        XCTAssertEqual(model.activityClause()?.render(),
                       "There are <a href=\"https://github.com/Alamofire/Alamofire/pulls\">5 open pull requests</a>. The last issue was closed 5 days ago and the last pull request was merged/closed 6 days ago.")
    }

    func test_activity_variants__missing_open_PRs() throws {
        var model = PackageShow.Model.mock
        model.activity?.openPullRequests = nil
        XCTAssertEqual(model.activityClause()?.render(),
                       "There are <a href=\"https://github.com/Alamofire/Alamofire/issues\">27 open issues</a>. The last issue was closed 5 days ago and the last pull request was merged/closed 6 days ago.")
    }

    func test_activity_variants__missing_open_issues_and_PRs() throws {
        var model = PackageShow.Model.mock
        model.activity?.openIssues = nil
        model.activity?.openPullRequests = nil
        XCTAssertEqual(model.activityClause()?.render(),
                       "The last issue was closed 5 days ago and the last pull request was merged/closed 6 days ago.")
    }

    func test_activity_variants__missing_last_closed_issue() throws {
        var model = PackageShow.Model.mock
        model.activity?.lastIssueClosedAt = nil
        XCTAssertEqual(model.activityClause()?.render(),
                       "There are <a href=\"https://github.com/Alamofire/Alamofire/issues\">27 open issues</a> and <a href=\"https://github.com/Alamofire/Alamofire/pulls\">5 open pull requests</a>. The last pull request was merged/closed 6 days ago.")
    }

    func test_activity_variants__missing_last_closed_PR() throws {
        var model = PackageShow.Model.mock
        model.activity?.lastPullRequestClosedAt = nil
        XCTAssertEqual(model.activityClause()?.render(),
                       "There are <a href=\"https://github.com/Alamofire/Alamofire/issues\">27 open issues</a> and <a href=\"https://github.com/Alamofire/Alamofire/pulls\">5 open pull requests</a>. The last issue was closed 5 days ago.")
    }

    func test_activity_variants__missing_last_closed_issue_and_PR() throws {
        var model = PackageShow.Model.mock
        model.activity?.lastIssueClosedAt = nil
        model.activity?.lastPullRequestClosedAt = nil
        XCTAssertEqual(model.activityClause()?.render(),
                       "There are <a href=\"https://github.com/Alamofire/Alamofire/issues\">27 open issues</a> and <a href=\"https://github.com/Alamofire/Alamofire/pulls\">5 open pull requests</a>. ")
    }

    func test_activity_variants__missing_everything() throws {
        var model = PackageShow.Model.mock
        model.activity?.openIssues = nil
        model.activity?.openPullRequests = nil
        model.activity?.lastIssueClosedAt = nil
        model.activity?.lastPullRequestClosedAt = nil
        XCTAssertEqual(model.activityClause()?.render(), nil)
    }

}


// local typealiases / references to make tests more readable
fileprivate typealias Version = PackageShow.Model.Version
let lpInfoGroups = PackageShow.Model.lpInfoGroups
