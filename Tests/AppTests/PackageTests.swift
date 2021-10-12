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

import Fluent
import Vapor
import XCTVapor


final class PackageTests: AppTestCase {

    func test_Equatable() throws {
        XCTAssertEqual(Package(id: .id0, url: "1".url),
                       Package(id: .id0, url: "2".url))
        XCTAssertFalse(Package() == Package())
        XCTAssertFalse(Package(id: .id0, url: "1".url) == Package())
    }

    func test_Hashable() throws {
        let packages: Set = [
            Package(id: .id0, url: "1".url),
            Package(id: .id0, url: "2".url),
            Package(url: "3".url),
            Package(url: "4".url)
        ]
        XCTAssertEqual(packages.map { "\($0.id)" }.sorted(),
                       [UUID.id0.uuidString, "nil", "nil"])
        XCTAssertEqual(packages.map { "\($0.url)" }.sorted(),
                       ["1", "3", "4"])
    }

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
            let readBack = try XCTUnwrap(Package.query(on: app.db).first().wait())
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
            "score": 17,
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
    
    func test_findDefaultBranchVersion() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, defaultBranch: "default").create(on: app.db).wait()
        let versions = [
            try Version(package: pkg, reference: .branch("branch")),
            try Version(package: pkg, commitDate: daysAgo(1), reference: .branch("default")),
            try Version(package: pkg, reference: .tag(.init(1, 2, 3))),
            try Version(package: pkg, commitDate: daysAgo(3), reference: .tag(.init(2, 1, 0))),
            try Version(package: pkg, commitDate: daysAgo(2), reference: .tag(.init(3, 0, 0, "beta"))),
        ]
        try versions.create(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: pkg.id!).wait()

        // MUT
        let version = jpr.findDefaultBranchVersion(versions)
        
        // validation
        XCTAssertEqual(version?.reference, .branch("default"))
    }
    
    // TODO: move most/all of the JPRVB MUT tests into JRVBTests file
    
    func test_query_owner_repository() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1".url)
        try Repository(package: pkg,
                       defaultBranch: "main",
                       forks: 42,
                       license: .mit,
                       name: "bar",
                       owner: "foo",
                       stars: 17,
                       summary: "summary").save(on: app.db).wait()
        let version = try App.Version(package: pkg,
                                      packageName: "test package",
                                      reference: .branch("main"))
        try version.save(on: app.db).wait()
        
        // MUT
        let p = try JPRVB.query(on: app.db, owner: "foo", repository: "bar").wait()
        
        // validate
        XCTAssertEqual(p.model.id, pkg.id)
        XCTAssertEqual(p.repository?.name, "bar")
    }
    
    func test_query_owner_repository_case_insensitivity() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1".url)
        try Repository(package: pkg,
                       defaultBranch: "main",
                       forks: 42,
                       license: .mit,
                       name: "bar",
                       owner: "foo",
                       stars: 17,
                       summary: "summary").save(on: app.db).wait()
        let version = try App.Version(package: pkg,
                                      packageName: "test package",
                                      reference: .branch("main"))
        try version.save(on: app.db).wait()
        
        // MUT
        let p = try JPRVB.query(on: app.db, owner: "Foo", repository: "bar").wait()
        
        // validate
        XCTAssertEqual(p.model.id, pkg.id)
    }

    func test_findRelease() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        let versions: [Version] = [
            try .init(package: p, reference: .tag(2, 0, 0)),
            try .init(package: p, reference: .tag(1, 2, 3)),
            try .init(package: p, reference: .tag(1, 5, 0)),
            try .init(package: p, reference: .tag(2, 0, 0, "b1")),
        ]

        // MUT & validation
        XCTAssertEqual(Package.findRelease(versions)?.reference, .tag(2, 0, 0))
    }

    func test_findPreRelease() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        func t(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: seconds) }

        // MUT & validation
        XCTAssertEqual(
            Package.findPreRelease([
                try .init(package: p, commitDate: t(2), reference: .tag(3, 0, 0, "b1")),
                try .init(package: p, commitDate: t(0), reference: .tag(1, 2, 3)),
                try .init(package: p, commitDate: t(1), reference: .tag(2, 0, 0)),
            ],
            after: .tag(2, 0, 0))?.reference,
            .tag(3, 0, 0, "b1")
        )
        // ensure a beta doesn't come after its release
        XCTAssertEqual(
            Package.findPreRelease([
                try .init(package: p, commitDate: t(3), reference: .tag(3, 0, 0)),
                try .init(package: p, commitDate: t(2), reference: .tag(3, 0, 0, "b1")),
                try .init(package: p, commitDate: t(0), reference: .tag(1, 2, 3)),
                try .init(package: p, commitDate: t(1), reference: .tag(2, 0, 0)),
            ],
            after: .tag(3, 0, 0))?.reference,
            nil
        )
    }

    func test_findPreRelease_double_digit_build() throws {
        // Test pre-release sorting of betas with double digit build numbers,
        // e.g. 2.0.0-b11 should come after 2.0.0-b9
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/706
        // setup
        let p = try savePackage(on: app.db, "1")
        func t(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: seconds) }

        // MUT & validation
        XCTAssertEqual(
            Package.findPreRelease([
                try .init(package: p, commitDate: t(0), reference: .tag(2, 0, 0, "b9")),
                try .init(package: p, commitDate: t(1), reference: .tag(2, 0, 0, "b10")),
                try .init(package: p, commitDate: t(2), reference: .tag(2, 0, 0, "b11")),
            ],
            after: nil)?.reference,
            .tag(2, 0, 0, "b11")
        )
    }

    func test_findSignificantReleases_old_beta() throws {
        // Test to ensure outdated betas aren't picked up as latest versions
        // setup
        let pkg = Package(id: UUID(), url: "1")
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg, defaultBranch: "main").save(on: app.db).wait()
        let versions = [
            try Version(package: pkg, packageName: "foo", reference: .branch("main")),
            try Version(package: pkg, packageName: "foo", reference: .tag(2, 0, 0)),
            try Version(package: pkg, packageName: "foo", reference: .tag(2, 0, 0, "rc1"))
        ]
        try versions.save(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: pkg.id!).wait()

        // MUT
        let (release, preRelease, defaultBranch) = jpr.findSignificantReleases(versions)

        // validate
        XCTAssertEqual(release?.reference, .tag(2, 0, 0))
        XCTAssertEqual(preRelease, nil)
        XCTAssertEqual(defaultBranch?.reference, .branch("main"))
    }

    func test_updateLatestVersions() throws {
        // setup
        func t(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: seconds) }
        let pkg = Package(id: UUID(), url: "1")
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg, defaultBranch: "main").save(on: app.db).wait()
        try Version(package: pkg, commitDate: t(2), packageName: "foo", reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: pkg, commitDate: t(0), packageName: "foo", reference: .tag(1, 2, 3))
            .save(on: app.db).wait()
        try Version(package: pkg, commitDate: t(1), packageName: "foo", reference: .tag(2, 0, 0, "rc1"))
            .save(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: pkg.id!).wait()

        // MUT
        try updateLatestVersions(on: app.db, package: jpr).wait()

        // validate
        try pkg.$versions.load(on: app.db).wait()
        let versions = pkg.versions.sorted(by: { $0.createdAt! < $1.createdAt! })
        XCTAssertEqual(versions.map(\.reference?.description), ["main", "1.2.3", "2.0.0-rc1"])
        XCTAssertEqual(versions.map(\.latest), [.defaultBranch, .release, .preRelease])
    }

    func test_updateLatestVersions_old_beta() throws {
        // Test to ensure outdated betas aren't picked up as latest versions
        // and that faulty db content (outdated beta marked as latest pre-release)
        // is correctly reset.
        // See https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/188
        // setup
        let pkg = Package(id: UUID(), url: "1")
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg, defaultBranch: "main").save(on: app.db).wait()
        try Version(package: pkg,
                    latest: .defaultBranch,
                    packageName: "foo",
                    reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: pkg,
                    latest: .release,
                    packageName: "foo",
                    reference: .tag(2, 0, 0))
            .save(on: app.db).wait()
        try Version(package: pkg,
                    latest: .preRelease,  // this should have been nil - ensure it's reset
                    packageName: "foo",
                    reference: .tag(2, 0, 0, "rc1"))
            .save(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: pkg.id!).wait()

        // MUT
        try updateLatestVersions(on: app.db, package: jpr).wait()

        // validate
        let versions = try Version.query(on: app.db)
            .sort(\.$createdAt).all().wait()
        XCTAssertEqual(versions.map(\.reference?.description), ["main", "2.0.0", "2.0.0-rc1"])
        XCTAssertEqual(versions.map(\.latest), [.defaultBranch, .release, nil])
    }

    func test_releaseInfo() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, defaultBranch: "default").create(on: app.db).wait()
        let versions = [
            try Version(package: pkg, reference: .branch("branch")),
            try Version(package: pkg, commitDate: daysAgo(1), reference: .branch("default")),
            try Version(package: pkg, reference: .tag(.init(1, 2, 3))),
            try Version(package: pkg, commitDate: daysAgo(3), reference: .tag(.init(2, 1, 0))),
            try Version(package: pkg, commitDate: daysAgo(2), reference: .tag(.init(3, 0, 0, "beta"))),
        ]
        try versions.create(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: pkg.id!).wait()
        // update versions
        try updateLatestVersions(on: app.db, package: jpr).wait()

        // MUT
        let info = PackageShow.releaseInfo(packageUrl: "1", versions: jpr.model.versions)
        
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
        try [
            try Version(package: pkg, commitDate: daysAgo(1), reference: .branch("default")),
            try Version(package: pkg, commitDate: daysAgo(3), reference: .tag(.init(2, 1, 0))),
            try Version(package: pkg, commitDate: daysAgo(2), reference: .tag(.init(2, 0, 0, "beta"))),
        ].create(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: pkg.id!).wait()
        // update versions
        try updateLatestVersions(on: app.db, package: jpr).wait()
        let versions = try pkg.$versions.load(on: app.db)
            .map { pkg.versions }
            .wait()

        // MUT
        let info = PackageShow.releaseInfo(packageUrl: "1", versions: versions)
        
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
        XCTAssertNoThrow(PackageShow.releaseInfo(packageUrl: "1", versions: versions))
    }

    func test_versionUrl() throws {
        XCTAssertEqual(Package(url: "https://github.com/foo/bar").versionUrl(for: .tag(1, 2, 3)),
                       "https://github.com/foo/bar/releases/tag/1.2.3")
        XCTAssertEqual(Package(url: "https://github.com/foo/bar").versionUrl(for: .branch("main")),
                       "https://github.com/foo/bar/tree/main")
        XCTAssertEqual(Package(url: "https://gitlab.com/foo/bar").versionUrl(for: .tag(1, 2, 3)),
                       "https://gitlab.com/foo/bar/-/tags/1.2.3")
        XCTAssertEqual(Package(url: "https://gitlab.com/foo/bar").versionUrl(for: .branch("main")),
                       "https://gitlab.com/foo/bar/-/tree/main")
        // ensure .git is stripped off
        XCTAssertEqual(Package(url: "https://github.com/foo/bar.git").versionUrl(for: .tag(1, 2, 3)),
                       "https://github.com/foo/bar/releases/tag/1.2.3")
    }

    func test_languagePlatformInfo() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, defaultBranch: "default").create(on: app.db).wait()
        try [
            try Version(package: pkg, reference: .branch("branch")),
            try Version(package: pkg,
                        commitDate: daysAgo(1),
                        reference: .branch("default"),
                        supportedPlatforms: [.macos("10.15"), .ios("13")],
                        swiftVersions: ["5.2", "5.3"].asSwiftVersions),
            try Version(package: pkg, reference: .tag(.init(1, 2, 3))),
            try Version(package: pkg,
                        commitDate: daysAgo(3),
                        reference: .tag(.init(2, 1, 0)),
                        supportedPlatforms: [.macos("10.13"), .ios("10")],
                        swiftVersions: ["4", "5"].asSwiftVersions),
            try Version(package: pkg,
                        commitDate: daysAgo(2),
                        reference: .tag(.init(3, 0, 0, "beta")),
                        supportedPlatforms: [.macos("10.14"), .ios("13")],
                        swiftVersions: ["5", "5.2"].asSwiftVersions),
        ].create(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: pkg.id!).wait()
        // update versions
        try updateLatestVersions(on: app.db, package: jpr).wait()
        let versions = try pkg.$versions.load(on: app.db)
            .map { pkg.versions }
            .wait()

        // MUT
        let lpInfo = JPRVB.languagePlatformInfo(packageUrl: "1", versions: versions)
        
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
        Current.date = {
            Date.init(timeIntervalSince1970: 1608000588)  // Dec 15, 2020
        }
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg,
                       commitCount: 1433,
                       defaultBranch: "default",
                       firstCommitDate: .t0,
                       name: "bar",
                       owner: "foo").create(on: app.db).wait()
        try (0..<10).forEach {
            try Version(package: pkg, reference: .tag(.init($0, 0, 0))).create(on: app.db).wait()
        }
        // add pre-release and default branch - these should *not* be counted as releases
        try Version(package: pkg, reference: .branch("main")).create(on: app.db).wait()
        try Version(package: pkg, reference: .tag(.init(2, 0, 0, "beta2"), "2.0.0beta2")).create(on: app.db).wait()
        let jprvb = try JPRVB.query(on: app.db, owner: "foo", repository: "bar").wait()
        
        // MUT
        let history = try XCTUnwrap(jprvb.history())
        
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
            try Version(package: pkg, reference: .tag(.init($0, 0, 0)))
                .save(on: app.db).wait()
        }
        let jpr = try Package.fetchCandidate(app.db, id: pkg.id!).wait()
        // update versions
        try updateLatestVersions(on: app.db, package: jpr).wait()
        let versions = try pkg.$versions.load(on: app.db)
            .map { pkg.versions }
            .wait()

        // MUT
        XCTAssertEqual(Score.compute(package: jpr, versions: versions), 67)
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
                       name: "bar",
                       openIssues: 27,
                       openPullRequests: 1,
                       owner: "foo").create(on: app.db).wait()
        let jprvb = try JPRVB.query(on: app.db, owner: "foo", repository: "bar").wait()

        // MUT
        let res = jprvb.activity()
        
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
    
    func test_buildResults_swiftVersions() throws {
        // Test build success reporting - we take any success across platforms
        // as a success for a particular x.y swift version (4.2, 5.0, etc, i.e.
        // ignoring swift patch versions)
        // setup
        let p = try savePackage(on: app.db, "1")
        let v = try Version(package: p, reference: .branch("main"))
        try v.save(on: app.db).wait()
        func makeBuild(_ status: Build.Status, _ platform: Build.Platform, _ version: SwiftVersion) throws {
            try Build(version: v, platform: platform, status: status, swiftVersion: version)
                .save(on: app.db)
                .wait()
        }
        // 5.0 - failed
        try makeBuild(.failed, .ios, .v5_0)
        try makeBuild(.failed, .macosXcodebuild, .v5_0)
        // 5.1 - no data - unknown
        // 5.2 - ok
        try makeBuild(.ok, .macosXcodebuild, .v5_2)
        // 5.3 - ok
        try makeBuild(.failed, .ios, .v5_3)
        try makeBuild(.ok, .macosXcodebuild, .v5_3)
        // 5.4 - ok
        try makeBuild(.failed, .ios, .v5_4)
        try makeBuild(.ok, .macosXcodebuild, .v5_4)
        try v.$builds.load(on: app.db).wait()
        
        // MUT
        let res: NamedBuildResults<SwiftVersionResults>? = JPRVB.buildResults(v)
        
        // validate
        XCTAssertEqual(res?.referenceName, "main")
        XCTAssertEqual(res?.results.v5_0, .init(parameter: .v5_0, status: .incompatible))
        XCTAssertEqual(res?.results.v5_1, .init(parameter: .v5_1, status: .unknown))
        XCTAssertEqual(res?.results.v5_2, .init(parameter: .v5_2, status: .compatible))
        XCTAssertEqual(res?.results.v5_3, .init(parameter: .v5_3, status: .compatible))
        XCTAssertEqual(res?.results.v5_4, .init(parameter: .v5_4, status: .compatible))
    }

    func test_buildResults_platforms() throws {
        // Test build success reporting - we take any success across swift versions
        // as a success for a particular platform
        // setup
        let p = try savePackage(on: app.db, "1")
        let v = try Version(package: p, reference: .branch("main"))
        try v.save(on: app.db).wait()
        func makeBuild(_ status: Build.Status, _ platform: Build.Platform, _ version: SwiftVersion) throws {
            try Build(version: v, platform: platform, status: status, swiftVersion: version)
                .save(on: app.db)
                .wait()
        }
        // ios - failed
        try makeBuild(.failed, .ios, .init(5, 2, 0))
        try makeBuild(.failed, .ios, .init(5, 0, 0))
        // macos - failed
        try makeBuild(.failed, .macosSpm, .init(5, 2, 0))
        try makeBuild(.failed, .macosXcodebuild, .init(5, 0, 0))
        // tvos - no data - unknown
        // watchos - ok
        try makeBuild(.failed, .watchos, .init(5, 2, 0))
        try makeBuild(.ok, .watchos, .init(5, 0, 0))
        try v.$builds.load(on: app.db).wait()

        // MUT
        let res: NamedBuildResults<PlatformResults>? = JPRVB.buildResults(v)

        // validate
        XCTAssertEqual(res?.referenceName, "main")
        XCTAssertEqual(res?.results.ios, .init(parameter: .ios, status: .incompatible))
        XCTAssertEqual(res?.results.macos, .init(parameter: .macos, status: .incompatible))
        XCTAssertEqual(res?.results.tvos, .init(parameter: .tvos, status: .unknown))
        XCTAssertEqual(res?.results.watchos, .init(parameter: .watchos, status: .compatible))
    }

    func test_swiftVersionBuildInfo() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p, name: "bar", owner: "foo").save(on: app.db).wait()
        let v = try Version(package: p, reference: .tag(.init(1, 2, 3)))
        try v.save(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: p.id!).wait()
        // update versions
        try updateLatestVersions(on: app.db, package: jpr).wait()
        // add builds
        try Build(version: v, platform: .macosXcodebuild, status: .ok, swiftVersion: .init(5, 2, 2))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .ios, status: .failed, swiftVersion: .init(5, 0, 2))
            .save(on: app.db)
            .wait()
        let jprvb = try JPRVB.query(on: app.db, owner: "foo", repository: "bar").wait()

        // MUT
        let res = jprvb.swiftVersionBuildInfo()
        
        // validate
        XCTAssertEqual(res?.stable?.referenceName, "1.2.3")
        XCTAssertEqual(res?.stable?.results.v5_0, .init(parameter: .v5_0, status: .incompatible))
        XCTAssertEqual(res?.stable?.results.v5_1, .init(parameter: .v5_1, status: .unknown))
        XCTAssertEqual(res?.stable?.results.v5_2, .init(parameter: .v5_2, status: .compatible))
        XCTAssertEqual(res?.stable?.results.v5_3, .init(parameter: .v5_3, status: .unknown))
        XCTAssertEqual(res?.stable?.results.v5_4, .init(parameter: .v5_4, status: .unknown))
        XCTAssertNil(res?.beta)
        XCTAssertNil(res?.latest)
    }

    func test_platformBuildInfo() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p, name: "bar", owner: "foo").save(on: app.db).wait()
        let v = try Version(package: p, reference: .tag(.init(1, 2, 3)))
        try v.save(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: p.id!).wait()
        // update versions
        _ = try updateLatestVersions(on: app.db, package: jpr).wait()
        // add builds
        try Build(version: v, platform: .macosXcodebuild, status: .ok, swiftVersion: .init(5, 2, 2))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .tvos, status: .failed, swiftVersion: .init(5, 2, 2))
            .save(on: app.db)
            .wait()
        let jprvb = try JPRVB.query(on: app.db, owner: "foo", repository: "bar").wait()

        // MUT
        let res = jprvb.platformBuildInfo()

        // validate
        XCTAssertEqual(res?.stable?.referenceName, "1.2.3")
        XCTAssertEqual(res?.stable?.results.ios, .init(parameter: .ios, status: .unknown))
        XCTAssertEqual(res?.stable?.results.macos, .init(parameter: .macos, status: .compatible))
        XCTAssertEqual(res?.stable?.results.tvos, .init(parameter: .tvos, status: .incompatible))
        XCTAssertEqual(res?.stable?.results.watchos, .init(parameter: .watchos, status: .unknown))
        XCTAssertNil(res?.beta)
        XCTAssertNil(res?.latest)
    }

    func test_badgeMessage_swiftVersions() throws {
        XCTAssertEqual(JPRVB.badgeMessage(swiftVersions: [.v5_2, .v5_1, .v5_4]), "5.4 | 5.2 | 5.1")
        XCTAssertNil(JPRVB.badgeMessage(swiftVersions: []))
    }

    func test_badgeMessage_platforms() throws {
        XCTAssertEqual(JPRVB.badgeMessage(platforms: [.linux, .ios, .macosXcodebuild, .macosSpm]),
                       "iOS | macOS | Linux")
        XCTAssertNil(JPRVB.badgeMessage(platforms: []))
    }

    func test_swiftVersionCompatibility() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p, name: "bar", owner: "foo").save(on: app.db).wait()
        let v = try Version(package: p, reference: .tag(.init(1, 2, 3)))
        try v.save(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: p.id!).wait()
        // update versions
        try updateLatestVersions(on: app.db, package: jpr).wait()
        // add builds
        try Build(version: v, platform: .linux, status: .ok, swiftVersion: .init(5, 3, 0))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .macosXcodebuild, status: .ok, swiftVersion: .init(5, 2, 2))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .ios, status: .failed, swiftVersion: .init(5, 0, 2))
            .save(on: app.db)
            .wait()
        let jprvb = try JPRVB.query(on: app.db, owner: "foo", repository: "bar").wait()

        // MUT
        let res = try XCTUnwrap(jprvb.swiftVersionCompatibility().values)

        // validate
        XCTAssertEqual(res.sorted(), [.v5_2, .v5_3])
    }
    
    func test_swiftVersionCompatibility_allPending() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p, name: "bar", owner: "foo").save(on: app.db).wait()
        let v = try Version(package: p, reference: .tag(.init(1, 2, 3)))
        try v.save(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: p.id!).wait()
        // update versions
        try updateLatestVersions(on: app.db, package: jpr).wait()
        // add builds
        try Build(version: v, platform: .linux, status: .triggered, swiftVersion: .init(5, 3, 0))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .macosXcodebuild, status: .triggered, swiftVersion: .init(5, 2, 2))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .ios, status: .triggered, swiftVersion: .init(5, 0, 2))
            .save(on: app.db)
            .wait()
        let jprvb = try JPRVB.query(on: app.db, owner: "foo", repository: "bar").wait()

        // MUT
        let res = jprvb.swiftVersionCompatibility()

        // validate
        XCTAssertEqual(res, .pending)
    }
    
    func test_swiftVersionCompatibility_partialPending() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p, name: "bar", owner: "foo").save(on: app.db).wait()
        let v = try Version(package: p, reference: .tag(.init(1, 2, 3)))
        try v.save(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: p.id!).wait()
        // update versions
        try updateLatestVersions(on: app.db, package: jpr).wait()
        // add builds
        try Build(version: v, platform: .linux, status: .ok, swiftVersion: .init(5, 3, 0))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .macosXcodebuild, status: .failed, swiftVersion: .init(5, 2, 2))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .ios, status: .triggered, swiftVersion: .init(5, 0, 2))
            .save(on: app.db)
            .wait()
        let jprvb = try JPRVB.query(on: app.db, owner: "foo", repository: "bar").wait()

        // MUT
        let res = try XCTUnwrap(jprvb.swiftVersionCompatibility().values)

        // validate
        XCTAssertEqual(res.sorted(), [ .v5_3 ])
    }

    func test_platformCompatibility() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p, name: "bar", owner: "foo").save(on: app.db).wait()
        let v = try Version(package: p, reference: .tag(.init(1, 2, 3)))
        try v.save(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: p.id!).wait()
        // update versions
        try updateLatestVersions(on: app.db, package: jpr).wait()
        // add builds
        try Build(version: v, platform: .linux, status: .ok, swiftVersion: .init(5, 3, 0))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .macosXcodebuild, status: .ok, swiftVersion: .init(5, 2, 2))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .ios, status: .failed, swiftVersion: .init(5, 0, 2))
            .save(on: app.db)
            .wait()
        let jprvb = try JPRVB.query(on: app.db, owner: "foo", repository: "bar").wait()

        // MUT
        let res = try XCTUnwrap(jprvb.platformCompatibility().values)

        // validate
        XCTAssertEqual(res.sorted(), [.macosXcodebuild, .linux])
    }
    
    func test_platformCompatibility_allPending() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p, name: "bar", owner: "foo").save(on: app.db).wait()
        let v = try Version(package: p, reference: .tag(.init(1, 2, 3)))
        try v.save(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: p.id!).wait()
        // update versions
        try updateLatestVersions(on: app.db, package: jpr).wait()
        // add builds
        try Build(version: v, platform: .linux, status: .triggered, swiftVersion: .init(5, 3, 0))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .macosXcodebuild, status: .triggered, swiftVersion: .init(5, 2, 2))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .ios, status: .triggered, swiftVersion: .init(5, 0, 2))
            .save(on: app.db)
            .wait()
        let jprvb = try JPRVB.query(on: app.db, owner: "foo", repository: "bar").wait()

        // MUT
        let res = jprvb.platformCompatibility()

        // validate
        XCTAssertEqual(res, .pending)
    }
    
    func test_platformCompatibility_partialPending() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p, name: "bar", owner: "foo").save(on: app.db).wait()
        let v = try Version(package: p, reference: .tag(.init(1, 2, 3)))
        try v.save(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: p.id!).wait()
        // update versions
        try updateLatestVersions(on: app.db, package: jpr).wait()
        // add builds
        try Build(version: v, platform: .linux, status: .ok, swiftVersion: .init(5, 3, 0))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .macosXcodebuild, status: .failed, swiftVersion: .init(5, 2, 2))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .ios, status: .triggered, swiftVersion: .init(5, 0, 2))
            .save(on: app.db)
            .wait()
        let jprvb = try JPRVB.query(on: app.db, owner: "foo", repository: "bar").wait()

        // MUT
        let res = try XCTUnwrap(jprvb.platformCompatibility().values)

        // validate
        XCTAssertEqual(res.sorted(), [ .linux ])
    }

    func test_isNew() throws {
        // setup
        let url = "1".asGithubUrl
        Current.fetchMetadata = { _, pkg in self.future(.mock(for: pkg)) }
        Current.fetchPackageList = { _ in self.future([url.url]) }
        Current.git.commitCount = { _ in 12 }
        Current.git.firstCommitDate = { _ in Date(timeIntervalSince1970: 0) }
        Current.git.getTags = { _ in [] }
        Current.git.lastCommitDate = { _ in Date(timeIntervalSince1970: 1) }
        Current.git.revisionInfo = { _, _ in
            .init(commit: "sha",
                  date: Date(timeIntervalSince1970: 0))
        }
        Current.shell.run = { cmd, path in
            if cmd.string.hasSuffix("swift package dump-package") {
                return #"{ "name": "Mock", "products": [] }"#
            }
            return ""
        }
        // run reconcile to ingest package
        try reconcile(client: app.client, database: app.db).wait()
        XCTAssertEqual(try Package.query(on: app.db).count().wait(), 1)

        // MUT & validate
        do {
            let pkg = try XCTUnwrap(Package.query(on: app.db).first().wait())
            XCTAssertTrue(pkg.isNew)
        }

        // run ingestion to progress package through pipeline
        try ingest(client: app.client, database: app.db, logger: app.logger, limit: 10).wait()

        // MUT & validate
        do {
            let pkg = try XCTUnwrap(Package.query(on: app.db).first().wait())
            XCTAssertTrue(pkg.isNew)
        }

        // run analysis to progress package through pipeline
        try analyze(client: app.client,
                    database: app.db,
                    logger: app.logger,
                    threadPool: app.threadPool,
                    limit: 10).wait()

        // MUT & validate
        do {
            let pkg = try XCTUnwrap(Package.query(on: app.db).first().wait())
            XCTAssertFalse(pkg.isNew)
        }

        // run stages again to simulate the cycle...

        try reconcile(client: app.client, database: app.db).wait()
        do {
            let pkg = try XCTUnwrap(Package.query(on: app.db).first().wait())
            XCTAssertFalse(pkg.isNew)
        }

        Current.date = { Date().addingTimeInterval(Constants.reIngestionDeadtime) }
        try ingest(client: app.client, database: app.db, logger: app.logger, limit: 10).wait()
        do {
            let pkg = try XCTUnwrap(Package.query(on: app.db).first().wait())
            XCTAssertFalse(pkg.isNew)
        }

        try analyze(client: app.client,
                    database: app.db,
                    logger: app.logger,
                    threadPool: app.threadPool,
                    limit: 10).wait()
        do {
            let pkg = try XCTUnwrap(Package.query(on: app.db).first().wait())
            XCTAssertFalse(pkg.isNew)
        }
    }

    func test_isNew_processingStage_nil() {
        // ensure a package with processingStage == nil is new
        // MUT & validate
        let pkg = Package(url: "1", processingStage: nil)
        XCTAssertTrue(pkg.isNew)
    }

}


func daysAgo(_ days: Int) -> Date {
    Calendar.current.date(byAdding: .init(day: -days), to: Date())!
}


typealias NamedBuildResults = PackageShow.Model.NamedBuildResults
typealias SwiftVersionResults = PackageShow.Model.SwiftVersionResults
typealias PlatformResults = PackageShow.Model.PlatformResults
