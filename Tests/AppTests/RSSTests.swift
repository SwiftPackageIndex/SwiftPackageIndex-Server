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

import SnapshotTesting
import XCTVapor


@MainActor
class RSSTests: SnapshotTestCase {

    func test_recentPackage_rssGuid() throws {
        let recentPackage = RecentPackage.mock(repositoryOwner: "owner", repositoryName: "name")
        XCTAssertEqual(recentPackage.rssGuid, "owner/name")
    }

    func test_recentRelease_rssGuid() throws {
        let recentRelease = RecentRelease.mock(repositoryOwner: "owner", repositoryName: "name", version: "version")
        XCTAssertEqual(recentRelease.rssGuid, "owner/name/version")
    }

    func test_render_item() throws {
        let item = RecentPackage.mock().rssItem

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
                            RecentPackage.mock(id: .id0,
                                               repositoryOwner: "repositoryOwner0",
                                               repositoryName: "repositoryName0",
                                               packageName: "packageName0",
                                               packageSummary: "packageSummary0",
                                               createdAt: .t0).rssItem,
                            RecentPackage.mock(id: .id1,
                                               repositoryOwner: "repositoryOwner1",
                                               repositoryName: "repositoryName1",
                                               packageName: "packageName1",
                                               packageSummary: "packageSummary1",
                                               createdAt: .t1).rssItem
                           ]
        )

        // MUT + validation
        assertSnapshot(matching: feed.rss.render(indentedBy: .spaces(2)),
                       as: .init(pathExtension: "xml", diffing: .lines))
    }

    func test_recentPackages() async throws {
        // setup
        for idx in 1...10 {
            let pkg = Package(id: UUID(), url: "\(idx)".asGithubUrl.url)
            try await pkg.save(on: app.db)
            // re-write creation date to something stable for snapshotting
            pkg.createdAt = Date(timeIntervalSince1970: TimeInterval(100*idx))
            try await pkg.save(on: app.db)
            try await Repository(package: pkg,
                                 name: "pkg-\(idx)",
                                 owner: "owner-\(idx)",
                                 summary: "Summary").create(on: app.db)
            try await Version(package: pkg, packageName: "pkg-\(idx)").save(on: app.db)
        }
        // make sure to refresh the materialized view
        try await RecentPackage.refresh(on: app.db).get()

        // MUT
        let feed = try await RSSFeed.recentPackages(on: app.db, limit: 8)

        // validation
        assertSnapshot(matching: feed.rss.render(indentedBy: .spaces(2)),
                       as: .init(pathExtension: "xml", diffing: .lines))
    }

    func test_Query_RecentRelease_filter() throws {
        do {
            let query = RSSFeed.Query(major: true, minor: nil, patch: false, pre: nil)
            XCTAssertEqual(query.filter, [.major])
        }
        do {
            let query = RSSFeed.Query(major: nil, minor: nil, patch: false, pre: nil)
            XCTAssertEqual(query.filter, .all)
        }
    }

    func test_recentReleases() throws {
        // setup
        try (1...10).forEach {
            let pkg = Package(id: UUID(), url: "\($0)".asGithubUrl.url)
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg,
                           name: "pkg-\($0)",
                           owner: "owner-\($0)",
                           summary: "Summary").create(on: app.db).wait()
            try Version(package: pkg,
                        commitDate: Date(timeIntervalSince1970: TimeInterval($0)),
                        packageName: "pkg-\($0)",
                        reference: .tag(.init($0, 0, 0), "\($0).0.0"),
                        releaseNotes: "Awesome Release Notes",
                        releaseNotesHTML: "<p>Awesome Release Notes</p>",
                        url: "https://example.com/release-url")
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
        try app.test(.GET, "packages.rss", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType,
                           .some(.init(type: "application", subType: "rss+xml")))
        })
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
                           name: "pkg-\($0)",
                           owner: "owner-\($0)",
                           summary: "Summary")
                .create(on: app.db).wait()
            try Version(package: pkg,
                        commitDate: Date(timeIntervalSince1970: TimeInterval($0)),
                        packageName: "pkg-\($0)",
                        reference: .tag(.init(major, minor, patch)),
                        url: "https://example.com/release-url")
                .save(on: app.db).wait()
        }
        // make sure to refresh the materialized view
        try RecentRelease.refresh(on: app.db).wait()

        // MUT
        try app.test(.GET, "releases.rss", afterResponse:  { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType,
                           .some(.init(type: "application", subType: "rss+xml")))
            // validation
            assertSnapshot(matching: String(decoding: res.body.readableBytesView, as: UTF8.self),
                           as: .init(pathExtension: "xml", diffing: .lines))
        })
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
                           name: "pkg-\($0)",
                           owner: "owner-\($0)",
                           summary: "Summary")
                .create(on: app.db).wait()
            try Version(package: pkg,
                        commitDate: Date(timeIntervalSince1970: TimeInterval($0)),
                        packageName: "pkg-\($0)",
                        reference: .tag(.init(major, minor, patch)),
                        url: "https://example.com/release-url")
                .save(on: app.db).wait()
        }
        // make sure to refresh the materialized view
        try RecentRelease.refresh(on: app.db).wait()

        // MUT
        try app.test(.GET, "releases.rss?major=true", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType,
                           .some(.init(type: "application", subType: "rss+xml")))
            // validation
            assertSnapshot(matching: String(decoding: res.body.readableBytesView, as: UTF8.self),
                           as: .init(pathExtension: "xml", diffing: .lines))
        })
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
                           name: "pkg-\($0)",
                           owner: "owner-\($0)",
                           summary: "Summary")
                .create(on: app.db).wait()
            try Version(package: pkg,
                        commitDate: Date(timeIntervalSince1970: TimeInterval($0)),
                        packageName: "pkg-\($0)",
                        reference: .tag(.init(major, minor, patch)),
                        url: "https://example.com/release-url")
                .save(on: app.db).wait()
        }
        // make sure to refresh the materialized view
        try RecentRelease.refresh(on: app.db).wait()

        // MUT
        try app.test(.GET, "releases.rss?major=true&minor=true", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType,
                           .some(.init(type: "application", subType: "rss+xml")))
            // validation
            assertSnapshot(matching: String(decoding: res.body.readableBytesView, as: UTF8.self),
                           as: .init(pathExtension: "xml", diffing: .lines))
        })
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
                           name: "pkg-\($0)",
                           owner: "owner-\($0)",
                           summary: "Summary")
                .create(on: app.db).wait()
            try Version(package: pkg,
                        commitDate: Date(timeIntervalSince1970: TimeInterval($0)),
                        packageName: "pkg-\($0)",
                        reference: .tag(.init(major, minor, patch, pre)),
                        url: "https://example.com/release-url")
                .save(on: app.db).wait()
        }
        // make sure to refresh the materialized view
        try RecentRelease.refresh(on: app.db).wait()

        // MUT
        try app.test(.GET, "releases.rss?pre=true", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType,
                           .some(.init(type: "application", subType: "rss+xml")))
            // validation
            assertSnapshot(matching: String(decoding: res.body.readableBytesView, as: UTF8.self),
                           as: .init(pathExtension: "xml", diffing: .lines))
        })
    }

}
