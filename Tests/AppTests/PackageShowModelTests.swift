@testable import App

import XCTVapor


class PackageShowModelTests: AppTestCase {
    
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
                                      reference: .branch("main"),
                                      packageName: nil)
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
                                      reference: .branch("main"),
                                      packageName: "test package")
        try version.save(on: app.db).wait()
        try Build(version: version,
                  platform: .macosXcodebuild,
                  status: .ok,
                  swiftVersion: .init(5, 2, 2))
            .save(on: app.db)
            .wait()
        // reload via query to ensure relationships are loaded
        pkg = try Package.query(on: app.db, owner: "foo", repository: "bar").wait()
        
        // MUT
        let m = PackageShow.Model(package: pkg)
        
        // validate
        XCTAssertNotNil(m?.swiftVersionBuildInfo?.latest)
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
    
    func test_stars_formatting() throws {
        var model = PackageShow.Model.mock
        model.stars = 999
        XCTAssertEqual(model.starsClause()?.render(), "999 stars.")
        model.stars = 1_000
        XCTAssertEqual(model.starsClause()?.render(), "1,000 stars.")
        model.stars = 1_000_000
        XCTAssertEqual(model.starsClause()?.render(), "1,000,000 stars.")
    }
    
    func test_groupBuildInfo() throws {
        let result1: BuildResults = .init(status4_2: .success,
                                          status5_0: .success,
                                          status5_1: .success,
                                          status5_2: .success,
                                          status5_3: .success)
        let result2: BuildResults = .init(status4_2: .failed,
                                          status5_0: .failed,
                                          status5_1: .failed,
                                          status5_2: .failed,
                                          status5_3: .failed)
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
                .init(references: [.init(name: "1.2.3", kind: .stable)], results: result1),
                .init(references: [.init(name: "2.0.0-b1", kind: .beta)], results: result2),
                .init(references: [.init(name: "main", kind: .branch)], results: result3),
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
                .init(references: [.init(name: "1.2.3", kind: .stable),
                                   .init(name: "main", kind: .branch)], results: result1),
                .init(references: [.init(name: "2.0.0-b1", kind: .beta)], results: result2),
            ])
        }
    }
    
}


// local typealiases / references to make tests more readable
fileprivate typealias Version = PackageShow.Model.Version
fileprivate typealias BuildInfo = PackageShow.Model.BuildInfo
fileprivate typealias BuildResults = PackageShow.Model.SwiftVersionResults
fileprivate typealias BuildStatusRow = PackageShow.Model.BuildStatusRow
let lpInfoGroups = PackageShow.Model.lpInfoGroups
