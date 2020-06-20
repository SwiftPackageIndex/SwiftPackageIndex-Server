@testable import App

import SnapshotTesting
import XCTVapor


class RSSTests: AppTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        record = false
    }

    func test_render_item() throws {
        let item = RecentPackage(id: UUID(),
                                 repositoryOwner: "owner",
                                 repositoryName: "repo",
                                 packageName: "package",
                                 packageSummary: "summary",
                                 createdAt: Date(timeIntervalSince1970: 0))
            .rssItem

        // MUT + validation
        assertSnapshot(matching: item.render(indentedBy: .spaces(2)),
                       as: .init(pathExtension: "xml", diffing: .lines))
    }

    func test_render_feed() throws {
        // Test generated feed. The result should validate successfully
        // on https://validator.w3.org/feed/check.cgi
        let feed = RSSFeed(title: "feed title", description: "feed description",
                           link: "https://SwiftPackageIndex.com",
                           items: [
                            RecentPackage(id: UUID(),
                                          repositoryOwner: "owner0",
                                          repositoryName: "repo0",
                                          packageName: "package0",
                                          packageSummary: "summary0",
                                createdAt: Date(timeIntervalSince1970: 0)).rssItem,
                            RecentPackage(id: UUID(),
                                          repositoryOwner: "owner1",
                                          repositoryName: "repo1",
                                          packageName: "package1",
                                          packageSummary: "summary1",
                                          createdAt: Date(timeIntervalSince1970: 1)).rssItem]
        )

        // MUT + validation
        assertSnapshot(matching: feed.rss.render(indentedBy: .spaces(2)),
                       as: .init(pathExtension: "xml", diffing: .lines))
    }

    func test_recentPackages() throws {
        // setup
        try (1...10).forEach {
            let pkg = Package(id: UUID(), url: "\($0)".asGithubUrl.url)
            try pkg.save(on: app.db).wait()
            // re-write creation date to something stable for snapshotting
            pkg.createdAt = Date(timeIntervalSince1970: TimeInterval(100*$0))
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg, summary: "Summary", name: "pkg-\($0)", owner: "owner-\($0)").create(on: app.db).wait()
            try Version(package: pkg, packageName: "pkg-\($0)").save(on: app.db).wait()
        }
        // make sure to refresh the materialized view
        try RecentPackage.refresh(on: app.db).wait()

        // MUT
        let feed = try RSSFeed.recentPackages(on: app.db, limit: 8).wait()

        // validation
        assertSnapshot(matching: feed.rss.render(indentedBy: .spaces(2)),
                       as: .init(pathExtension: "xml", diffing: .lines))
    }

    func test_recentReleases() throws {
        // setup
        try (1...10).forEach {
            let pkg = Package(id: UUID(), url: "\($0)".asGithubUrl.url)
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg, summary: "Summary", name: "pkg-\($0)", owner: "owner-\($0)").create(on: app.db).wait()
            try Version(package: pkg,
                        reference: .tag(.init($0, 0, 0), "\($0).0.0"),
                        packageName: "pkg-\($0)",
                        commitDate: Date(timeIntervalSince1970: TimeInterval($0)))
                .save(on: app.db).wait()
        }
        // make sure to refresh the materialized view
        try RecentRelease.refresh(on: app.db).wait()

        // MUT
        let feed = try RSSFeed.recentReleases(on: app.db, limit: 8).wait()

        // validation
        assertSnapshot(matching: feed.rss.render(indentedBy: .spaces(2)),
                       as: .init(pathExtension: "xml", diffing: .lines))
    }

    func test_recentPackages_route() throws {
        // Test request handler
        try app.test(.GET, "packages.rss") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType,
                           .some(.init(type: "application", subType: "rss+xml")))
        }
    }

    func test_recentReleases_route_all() throws {
        // Test request handler - without parameters (all)
        // setup
        // see RecentViewsTests.test_recentReleases_filter for filter results
        try (1...10).forEach {
            let major = $0 / 3  // 0, 0, 1, 1, 1, 2, 2, 2, 3, 3
            let minor = $0 % 3  // 1, 2, 0, 1, 2, 0, 1, 2, 0, 1
            let patch = $0 % 2  // 1, 0, 1, 0, 1, 0, 1, 0, 1, 0
            let pkg = Package(id: UUID(), url: "\($0)".asGithubUrl.url)
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg,
                           summary: "Summary",
                           name: "pkg-\($0)",
                           owner: "owner-\($0)")
                .create(on: app.db).wait()
            try Version(package: pkg,
                        reference: .tag(.init(major, minor, patch)),
                        packageName: "pkg-\($0)",
                        commitDate: Date(timeIntervalSince1970: TimeInterval($0)))
                .save(on: app.db).wait()
        }
        // make sure to refresh the materialized view
        try RecentRelease.refresh(on: app.db).wait()

        // MUT
        try app.test(.GET, "releases.rss") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType,
                           .some(.init(type: "application", subType: "rss+xml")))
            // validation
            assertSnapshot(matching: String(decoding: res.body.readableBytesView, as: UTF8.self),
                           as: .init(pathExtension: "xml", diffing: .lines))
        }
    }

    func test_recentReleases_route_major() throws {
        // Test request handler - major releases only
        // setup
        // see RecentViewsTests.test_recentReleases_filter for filter results
        try (1...10).forEach {
            let major = $0 / 3  // 0, 0, 1, 1, 1, 2, 2, 2, 3, 3
            let minor = $0 % 3  // 1, 2, 0, 1, 2, 0, 1, 2, 0, 1
            let patch = $0 % 2  // 1, 0, 1, 0, 1, 0, 1, 0, 1, 0
            let pkg = Package(id: UUID(), url: "\($0)".asGithubUrl.url)
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg,
                           summary: "Summary",
                           name: "pkg-\($0)",
                           owner: "owner-\($0)")
                .create(on: app.db).wait()
            try Version(package: pkg,
                        reference: .tag(.init(major, minor, patch)),
                        packageName: "pkg-\($0)",
                        commitDate: Date(timeIntervalSince1970: TimeInterval($0)))
                .save(on: app.db).wait()
        }
        // make sure to refresh the materialized view
        try RecentRelease.refresh(on: app.db).wait()

        // MUT
        try app.test(.GET, "releases.rss?major=true") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType,
                           .some(.init(type: "application", subType: "rss+xml")))
            // validation
            assertSnapshot(matching: String(decoding: res.body.readableBytesView, as: UTF8.self),
                           as: .init(pathExtension: "xml", diffing: .lines))
        }
    }

    func test_recentReleases_route_majorMinor() throws {
        // Test request handler - major & minor releases only
        // setup
        // see RecentViewsTests.test_recentReleases_filter for filter results
        try (1...10).forEach {
            let major = $0 / 3  // 0, 0, 1, 1, 1, 2, 2, 2, 3, 3
            let minor = $0 % 3  // 1, 2, 0, 1, 2, 0, 1, 2, 0, 1
            let patch = $0 % 2  // 1, 0, 1, 0, 1, 0, 1, 0, 1, 0
            let pkg = Package(id: UUID(), url: "\($0)".asGithubUrl.url)
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg,
                           summary: "Summary",
                           name: "pkg-\($0)",
                           owner: "owner-\($0)")
                .create(on: app.db).wait()
            try Version(package: pkg,
                        reference: .tag(.init(major, minor, patch)),
                        packageName: "pkg-\($0)",
                        commitDate: Date(timeIntervalSince1970: TimeInterval($0)))
                .save(on: app.db).wait()
        }
        // make sure to refresh the materialized view
        try RecentRelease.refresh(on: app.db).wait()

        // MUT
        try app.test(.GET, "releases.rss?major=true&minor=true") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType,
                           .some(.init(type: "application", subType: "rss+xml")))
            // validation
            assertSnapshot(matching: String(decoding: res.body.readableBytesView, as: UTF8.self),
                           as: .init(pathExtension: "xml", diffing: .lines))
        }
    }

    func test_recentReleases_route_preRelease() throws {
        // Test request handler - pre-releases only
        // setup
        // see RecentViewsTests.test_recentReleases_filter for filter results
        try (1...12).forEach {
            let major = $0 / 3  // 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4
            let minor = $0 % 3  // 1, 2, 0, 1, 2, 0, 1, 2, 0, 1, 2, 0
            let patch = $0 % 2  // 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0
            let pre = $0 <= 10 ? "" : "b1"
            let pkg = Package(id: UUID(), url: "\($0)".asGithubUrl.url)
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg,
                           summary: "Summary",
                           name: "pkg-\($0)",
                           owner: "owner-\($0)")
                .create(on: app.db).wait()
            try Version(package: pkg,
                        reference: .tag(.init(major, minor, patch, pre)),
                        packageName: "pkg-\($0)",
                        commitDate: Date(timeIntervalSince1970: TimeInterval($0)))
                .save(on: app.db).wait()
        }
        // make sure to refresh the materialized view
        try RecentRelease.refresh(on: app.db).wait()

        // MUT
        try app.test(.GET, "releases.rss?pre=true") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType,
                           .some(.init(type: "application", subType: "rss+xml")))
            // validation
            assertSnapshot(matching: String(decoding: res.body.readableBytesView, as: UTF8.self),
                           as: .init(pathExtension: "xml", diffing: .lines))
        }
    }

}
