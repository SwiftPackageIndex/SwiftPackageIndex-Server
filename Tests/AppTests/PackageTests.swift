@testable import App

import Fluent
import Vapor
import XCTVapor


final class PackageTests: AppTestCase {
    
    func test_cacheDirectoryName() throws {
        XCTAssertEqual(
            Package(url: "https://github.com/finestructure/Arena").cacheDirectoryName,
            "github.com-finestructure-arena")
        XCTAssertEqual(
            Package(url: "https://github.com/finestructure/Arena.git").cacheDirectoryName,
            "github.com-finestructure-arena")
        XCTAssertEqual(
            Package(url: "http://github.com/finestructure/Arena.git").cacheDirectoryName,
            "github.com-finestructure-arena")
        XCTAssertEqual(
            Package(url: "http://github.com/FINESTRUCTURE/ARENA.GIT").cacheDirectoryName,
            "github.com-finestructure-arena")
        XCTAssertEqual(Package(url: "foo").cacheDirectoryName, nil)
        XCTAssertEqual(Package(url: "http://foo").cacheDirectoryName, nil)
        XCTAssertEqual(Package(url: "file://foo").cacheDirectoryName, nil)
        XCTAssertEqual(Package(url: "http:///foo/bar").cacheDirectoryName, nil)
    }

    func test_save_status() throws {
        do {  // default status
            let pkg = Package()  // avoid using init with default argument in order to test db default
            pkg.url = "1"
            try pkg.save(on: app.db).wait()
            let readBack = try XCTUnwrap(try Package.query(on: app.db).first().wait())
            XCTAssertEqual(readBack.status, .new)
        }
        do {  // with status
            try Package(url: "2", status: .ok).save(on: app.db).wait()
            let pkg = try XCTUnwrap(try Package.query(on: app.db).filter(by: "2").first().wait())
            XCTAssertEqual(pkg.status, .ok)
        }
    }

    func test_encode() throws {
        let p = Package(id: UUID(), url: URL(string: "https://github.com/finestructure/Arena")!)
        p.status = .ok
        let data = try JSONEncoder().encode(p)
        XCTAssertTrue(!data.isEmpty)
    }

    func test_decode_date() throws {
        let json = """
        {
            "id": "CAFECAFE-CAFE-CAFE-CAFE-CAFECAFECAFE",
            "url": "https://github.com/finestructure/Arena",
            "status": "ok",
            "createdAt": 0,
            "updatedAt": 1
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let p = try decoder.decode(Package.self, from: Data(json.utf8))
        XCTAssertEqual(p.id?.uuidString, "CAFECAFE-CAFE-CAFE-CAFE-CAFECAFECAFE")
        XCTAssertEqual(p.url, "https://github.com/finestructure/Arena")
        XCTAssertEqual(p.status, .ok)
        XCTAssertEqual(p.createdAt, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(p.updatedAt, Date(timeIntervalSince1970: 1))
    }

    func test_unique_url() throws {
        try Package(url: "p1").save(on: app.db).wait()
        XCTAssertThrowsError(try Package(url: "p1").save(on: app.db).wait())
    }

    func test_filter_by_url() throws {
        try ["https://foo.com/1", "https://foo.com/2"].forEach {
            try Package(url: $0).save(on: app.db).wait()
        }
        let res = try Package.query(on: app.db).filter(by: "https://foo.com/1").all().wait()
        XCTAssertEqual(res.map(\.url), ["https://foo.com/1"])
    }

    func test_repository() throws {
        let pkg = try savePackage(on: app.db, "1")
        do {
            let pkg = try XCTUnwrap(Package.query(on: app.db).with(\.$repositories).first().wait())
            XCTAssertEqual(pkg.repository, nil)
        }
        do {
            let repo = try Repository(package: pkg)
            try repo.save(on: app.db).wait()
            let pkg = try XCTUnwrap(Package.query(on: app.db).with(\.$repositories).first().wait())
            XCTAssertEqual(pkg.repository, repo)
        }
    }

    func test_versions() throws {
        let pkg = try savePackage(on: app.db, "1")
        let versions = [
            try Version(package: pkg, reference: .branch("branch")),
            try Version(package: pkg, reference: .branch("default")),
            try Version(package: pkg, reference: .tag(.init(1, 2, 3))),
        ]
        try versions.create(on: app.db).wait()
        do {
            let pkg = try XCTUnwrap(Package.query(on: app.db).with(\.$versions).first().wait())
            XCTAssertEqual(pkg.versions.count, 3)
        }
    }

    func test_defaultVersion() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, defaultBranch: "default").create(on: app.db).wait()
        let versions = [
            try Version(package: pkg, reference: .branch("branch")),
            try Version(package: pkg, reference: .branch("default"), commitDate: daysAgo(1)),
            try Version(package: pkg, reference: .tag(.init(1, 2, 3))),
            try Version(package: pkg, reference: .tag(.init(2, 1, 0)), commitDate: daysAgo(3)),
            try Version(package: pkg, reference: .tag(.init(3, 0, 0, "beta")), commitDate: daysAgo(2)),
        ]
        try versions.create(on: app.db).wait()
        try pkg.$repositories.load(on: app.db)
            .flatMap { pkg.$versions.load(on: self.app.db) }
            .wait()

        // MUT
        let version = pkg.defaultVersion()

        // validation
        XCTAssertEqual(version?.reference, .branch("default"))
    }

    func test_defaultVersion_eagerLoading() throws {
        // Ensure failure to eager load doesn't trigger a fatalError
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, defaultBranch: "branch").create(on: app.db).wait()
        let version = try Version(package: pkg, reference: .branch("branch"))
        try version.create(on: app.db).wait()

        // MUT / validation

        do {  // no eager loading
            XCTAssertNil(pkg.$versions.value)
            XCTAssertNil(pkg.defaultVersion())
        }

        do {  // load eagerly
            let pkg = try XCTUnwrap(Package.query(on: app.db)
                .with(\.$repositories)
                .with(\.$versions)
                .first().wait())
            XCTAssertNotNil(pkg.$versions.value)
            XCTAssertEqual(pkg.defaultVersion(), version)
        }
    }

    func test_releaseInfo() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, defaultBranch: "default").create(on: app.db).wait()
        let versions = [
            try Version(package: pkg, reference: .branch("branch")),
            try Version(package: pkg, reference: .branch("default"), commitDate: daysAgo(1)),
            try Version(package: pkg, reference: .tag(.init(1, 2, 3))),
            try Version(package: pkg, reference: .tag(.init(2, 1, 0)), commitDate: daysAgo(3)),
            try Version(package: pkg, reference: .tag(.init(3, 0, 0, "beta")), commitDate: daysAgo(2)),
        ]
        try versions.create(on: app.db).wait()
        // re-load pkg with relationships
        try pkg.$repositories.load(on: app.db)
            .flatMap { pkg.$versions.load(on: self.app.db) }
            .wait()

        // MUT
        let info = pkg.releaseInfo()

        // validate
        XCTAssertEqual(info.stable?.date, "3 days ago")
        XCTAssertEqual(info.beta?.date, "2 days ago")
        XCTAssertEqual(info.latest?.date, "1 day ago")
    }

    func test_releaseInfo_exclude_old_betas() throws {
        // Test to ensure that we don't publish a beta that's older than stable
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, defaultBranch: "default").create(on: app.db).wait()
        let versions = [
            try Version(package: pkg, reference: .branch("default"), commitDate: daysAgo(1)),
            try Version(package: pkg, reference: .tag(.init(2, 1, 0)), commitDate: daysAgo(3)),
            try Version(package: pkg, reference: .tag(.init(2, 0, 0, "beta")), commitDate: daysAgo(2)),
        ]
        try versions.create(on: app.db).wait()
        // re-load pkg with relationships
        try pkg.$repositories.load(on: app.db)
            .flatMap { pkg.$versions.load(on: self.app.db) }
            .wait()

        // MUT
        let info = pkg.releaseInfo()

        // validate
        XCTAssertEqual(info.stable?.date, "3 days ago")
        XCTAssertEqual(info.beta, nil)
        XCTAssertEqual(info.latest?.date, "1 day ago")
    }

    func test_releaseInfo_nonEager() throws {
        // ensure non-eager access does not fatalError
        let pkg = try savePackage(on: app.db, "1")
        let versions = [
            try Version(package: pkg, reference: .branch("default")),
        ]
        try versions.create(on: app.db).wait()

        // MUT / validate
        XCTAssertNoThrow(pkg.releaseInfo)
    }

    func test_languagePlatformInfo() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, defaultBranch: "default").create(on: app.db).wait()
        let versions = [
            try Version(package: pkg, reference: .branch("branch")),
            try Version(package: pkg, reference: .branch("default"),
                        commitDate: daysAgo(1),
                        supportedPlatforms: [.macos("10.15"), .ios("13")],
                        swiftVersions: ["5.2", "5.3"].asSwiftVersions),
            try Version(package: pkg, reference: .tag(.init(1, 2, 3))),
            try Version(package: pkg, reference: .tag(.init(2, 1, 0)),
                        commitDate: daysAgo(3),
                        supportedPlatforms: [.macos("10.13"), .ios("10")],
                        swiftVersions: ["4", "5"].asSwiftVersions),
            try Version(package: pkg, reference: .tag(.init(3, 0, 0, "beta")),
                        commitDate: daysAgo(2),
                        supportedPlatforms: [.macos("10.14"), .ios("13")],
                        swiftVersions: ["5", "5.2"].asSwiftVersions),
        ]
        try versions.create(on: app.db).wait()
        // re-load pkg with relationships
        try pkg.$repositories.load(on: app.db)
            .flatMap { pkg.$versions.load(on: self.app.db) }
            .wait()

        // MUT
        let lpInfo = pkg.languagePlatformInfo()

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

    func test_history() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg,
                       commitCount: 1433,
                       firstCommitDate: Date(timeIntervalSince1970: 0),
                       defaultBranch: "default").create(on: app.db).wait()
        try (0..<10).forEach {
            try Version(package: pkg, reference: .tag(.init($0, 0, 0))).create(on: app.db).wait()
        }
        // add pre-release and default branch - these should *not* be counted as releases
        try Version(package: pkg, reference: .branch("main")).create(on: app.db).wait()
        try Version(package: pkg, reference: .tag(.init(2, 0, 0, "beta2"), "2.0.0beta2")).create(on: app.db).wait()
        // re-load pkg with relationships
        try pkg.$repositories.load(on: app.db)
            .flatMap { pkg.$versions.load(on: self.app.db) }
            .wait()

        // MUT
        let history = try XCTUnwrap(pkg.history())

        // validate
        XCTAssertEqual(history.since, "50 years")
        XCTAssertEqual(history.commitCount.label, "1,433 commits")
        XCTAssertEqual(history.commitCount.url, "1/commits/default")
        XCTAssertEqual(history.releaseCount.label, "10 releases")
        XCTAssertEqual(history.releaseCount.url, "1/releases")
    }

    func test_computeScore() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, defaultBranch: "default", stars: 10_000).save(on: app.db).wait()
        try Version(package: pkg,
                    reference: .branch("default"),
                    swiftVersions: ["5"].asSwiftVersions).save(on: app.db).wait()
        try (0..<20).forEach {
            try Version(package: pkg, reference: .tag(.init($0, 0, 0))).create(on: app.db).wait()
        }
        // re-load pkg with relationships
        try pkg.$repositories.load(on: app.db)
            .flatMap { pkg.$versions.load(on: self.app.db) }
            .wait()

        // MUT
        XCTAssertEqual(pkg.computeScore(), 67)
    }

    func test_activity() throws {
        // setup
        let m: TimeInterval = 60
        let H = 60*m
        let d = 24*H
        let pkg = try savePackage(on: app.db, "https://github.com/Alamofire/Alamofire")
        try Repository(package: pkg,
                       lastIssueClosedAt: Date(timeIntervalSinceNow: -5*d),
                       lastPullRequestClosedAt: Date(timeIntervalSinceNow: -6*d),
                       openIssues: 27,
                       openPullRequests: 1).create(on: app.db).wait()
        // re-load pkg with relationships
        try pkg.$repositories.load(on: app.db).wait()

        // MUT
        let res = pkg.activity()

        // validate
        XCTAssertEqual(res,
                       .init(openIssuesCount: 27,
                             openIssues: .init(label: "27 open issues",
                                               url: "https://github.com/Alamofire/Alamofire/issues"),
                             openPullRequests: .init(label: "1 open pull request",
                                                     url: "https://github.com/Alamofire/Alamofire/pulls"),
                             lastIssueClosedAt: "5 days ago",
                             lastPullRequestClosedAt: "6 days ago"))
    }
}


func daysAgo(_ days: Int) -> Date {
    Calendar.current.date(byAdding: .init(day: -days), to: Date())!
}
