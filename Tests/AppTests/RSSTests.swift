@testable import App

import SnapshotTesting
import XCTVapor


class RSSTests: AppTestCase {

    func test_render_item() throws {
        let item = RSSFeed.Item(.init(id: UUID(),
                                      repositoryOwner: "owner",
                                      repositoryName: "repo",
                                      packageName: "package",
                                      packageSummary: "summary",
                                      createdAt: Date(timeIntervalSince1970: 0)))

        // MUT + validation
        assertSnapshot(matching: item.node.render(indentedBy: .spaces(2)),
                       as: .init(pathExtension: "xml", diffing: .lines))
    }

    func test_render_feed() throws {
        // Test generated feed. The result should validate successfully
        // on https://validator.w3.org/feed/check.cgi
        let feed = RSSFeed(title: "feed title", description: "feed description",
                           link: "https://SwiftPackageIndex.com",
                           items: [
                            RSSFeed.Item(.init(id: UUID(),
                                               repositoryOwner: "owner0",
                                               repositoryName: "repo0",
                                               packageName: "package0",
                                               packageSummary: "summary0",
                                               createdAt: Date(timeIntervalSince1970: 0))),
                            RSSFeed.Item(.init(id: UUID(),
                                               repositoryOwner: "owner1",
                                               repositoryName: "repo1",
                                               packageName: "package1",
                                               packageSummary: "summary1",
                                               createdAt: Date(timeIntervalSince1970: 1)))]
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
            try Repository(package: pkg, name: "pkg-\($0)", owner: "owner-\($0)").create(on: app.db).wait()
            try Version(package: pkg, packageName: "pkg-\($0)").save(on: app.db).wait()
        }
        // make sure to refresh the materialized view
        try RecentPackage.refresh(on: app.db).wait()

        // MUT
        let feed = try RSSFeed.recentPackages(on: app.db, maxItemCount: 8).wait()

        // validation
        assertSnapshot(matching: feed.rss.render(indentedBy: .spaces(2)),
                       as: .init(pathExtension: "xml", diffing: .lines))
    }

    func test_recentReleases() throws {
        // setup
        try (1...10).forEach {
            let pkg = Package(id: UUID(), url: "\($0)".asGithubUrl.url)
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg, name: "pkg-\($0)", owner: "owner-\($0)").create(on: app.db).wait()
            try Version(package: pkg,
                        reference: .tag(.init($0, 0, 0), "\($0).0.0"),
                        packageName: "pkg-\($0)",
                        commitDate: Date(timeIntervalSince1970: TimeInterval($0)))
                .save(on: app.db).wait()
        }
        // make sure to refresh the materialized view
        try RecentRelease.refresh(on: app.db).wait()

        // MUT
        let feed = try RSSFeed.recentReleases(on: app.db, maxItemCount: 8).wait()

        // validation
        assertSnapshot(matching: feed.rss.render(indentedBy: .spaces(2)),
                       as: .init(pathExtension: "xml", diffing: .lines))
    }

    func test_recentPackages_route() throws {
        try app.test(.GET, "packages.rss") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType,
                           .some(.init(type: "application", subType: "rss+xml")))
        }
    }
}
