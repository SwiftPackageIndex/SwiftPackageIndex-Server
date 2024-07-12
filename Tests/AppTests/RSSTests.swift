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
        assertSnapshot(of: item.render(indentedBy: .spaces(2)),
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
        assertSnapshot(of: feed.rss.render(indentedBy: .spaces(2)),
                       as: .init(pathExtension: "xml", diffing: .lines))
    }

    @MainActor
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
        try await RecentPackage.refresh(on: app.db)

        // MUT
        let feed = try await RSSFeed.recentPackages(on: app.db, limit: 8)

        // validation
        assertSnapshot(of: feed.rss.render(indentedBy: .spaces(2)),
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

    @MainActor
    func test_recentReleases() async throws {
        // setup
        for idx in 1...10 {
            let pkg = Package(id: UUID(), url: "\(idx)".asGithubUrl.url)
            try await pkg.save(on: app.db)
            try await Repository(package: pkg,
                                 name: "pkg-\(idx)",
                                 owner: "owner-\(idx)",
                                 summary: "Summary").create(on: app.db)
            try await Version(package: pkg,
                              commitDate: Date(timeIntervalSince1970: TimeInterval(idx)),
                              packageName: "pkg-\(idx)",
                              reference: .tag(.init(idx, 0, 0), "\(idx).0.0"),
                              releaseNotes: "Awesome Release Notes",
                              releaseNotesHTML: "<p>Awesome Release Notes</p>",
                              url: "https://example.com/release-url")
            .save(on: app.db)
        }
        // make sure to refresh the materialized view
        try await RecentRelease.refresh(on: app.db)

        // MUT
        let feed = try await RSSFeed.recentReleases(on: app.db, limit: 8)

        // validation
        assertSnapshot(of: feed.rss.render(indentedBy: .spaces(2)),
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

    @MainActor
    func test_recentReleases_route_all() async throws {
        // Test request handler - without parameters (all)
        // setup
        // see RecentViewsTests.test_recentReleases_filter for filter results
        for idx in 1...10 {
            let major = idx / 3  // 0, 0, 1, 1, 1, 2, 2, 2, 3, 3
            let minor = idx % 3  // 1, 2, 0, 1, 2, 0, 1, 2, 0, 1
            let patch = idx % 2  // 1, 0, 1, 0, 1, 0, 1, 0, 1, 0
            let pkg = Package(id: UUID(), url: "\(idx)".asGithubUrl.url)
            try await pkg.save(on: app.db)
            try await Repository(package: pkg,
                                 name: "pkg-\(idx)",
                                 owner: "owner-\(idx)",
                                 summary: "Summary")
            .create(on: app.db)
            try await Version(package: pkg,
                              commitDate: Date(timeIntervalSince1970: TimeInterval(idx)),
                              packageName: "pkg-\(idx)",
                              reference: .tag(.init(major, minor, patch)),
                              url: "https://example.com/release-url")
            .save(on: app.db)
        }
        // make sure to refresh the materialized view
        try await RecentRelease.refresh(on: app.db)

        // MUT
        try await app.test(.GET, "releases.rss", afterResponse:  { @Sendable res async in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType,
                           .some(.init(type: "application", subType: "rss+xml")))
            // validation
            assertSnapshot(of: String(decoding: res.body.readableBytesView, as: UTF8.self),
                           as: .init(pathExtension: "xml", diffing: .lines))
        })
    }

    @MainActor
    func test_recentReleases_route_major() async throws {
        // Test request handler - major releases only
        // setup
        // see RecentViewsTests.test_recentReleases_filter for filter results
        for idx in 1...10 {
            let major = idx / 3  // 0, 0, 1, 1, 1, 2, 2, 2, 3, 3
            let minor = idx % 3  // 1, 2, 0, 1, 2, 0, 1, 2, 0, 1
            let patch = idx % 2  // 1, 0, 1, 0, 1, 0, 1, 0, 1, 0
            let pkg = Package(id: UUID(), url: "\(idx)".asGithubUrl.url)
            try await pkg.save(on: app.db)
            try await Repository(package: pkg,
                                 name: "pkg-\(idx)",
                                 owner: "owner-\(idx)",
                                 summary: "Summary")
            .create(on: app.db)
            try await Version(package: pkg,
                              commitDate: Date(timeIntervalSince1970: TimeInterval(idx)),
                              packageName: "pkg-\(idx)",
                              reference: .tag(.init(major, minor, patch)),
                              url: "https://example.com/release-url")
            .save(on: app.db)
        }
        // make sure to refresh the materialized view
        try await RecentRelease.refresh(on: app.db)

        // MUT
        try await app.test(.GET, "releases.rss?major=true", afterResponse: { @Sendable res async in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType,
                           .some(.init(type: "application", subType: "rss+xml")))
            // validation
            assertSnapshot(of: String(decoding: res.body.readableBytesView, as: UTF8.self),
                           as: .init(pathExtension: "xml", diffing: .lines))
        })
    }

    @MainActor
    func test_recentReleases_route_majorMinor() async throws {
        // Test request handler - major & minor releases only
        // setup
        // see RecentViewsTests.test_recentReleases_filter for filter results
        for idx in 1...10 {
            let major = idx / 3  // 0, 0, 1, 1, 1, 2, 2, 2, 3, 3
            let minor = idx % 3  // 1, 2, 0, 1, 2, 0, 1, 2, 0, 1
            let patch = idx % 2  // 1, 0, 1, 0, 1, 0, 1, 0, 1, 0
            let pkg = Package(id: UUID(), url: "\(idx)".asGithubUrl.url)
            try await pkg.save(on: app.db)
            try await Repository(package: pkg,
                           name: "pkg-\(idx)",
                           owner: "owner-\(idx)",
                           summary: "Summary")
                .create(on: app.db)
            try await Version(package: pkg,
                        commitDate: Date(timeIntervalSince1970: TimeInterval(idx)),
                        packageName: "pkg-\(idx)",
                        reference: .tag(.init(major, minor, patch)),
                        url: "https://example.com/release-url")
                .save(on: app.db)
        }
        // make sure to refresh the materialized view
        try await RecentRelease.refresh(on: app.db)

        // MUT
        try await app.test(.GET, "releases.rss?major=true&minor=true", afterResponse: { @Sendable res async in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType,
                           .some(.init(type: "application", subType: "rss+xml")))
            // validation
            assertSnapshot(of: String(decoding: res.body.readableBytesView, as: UTF8.self),
                           as: .init(pathExtension: "xml", diffing: .lines))
        })
    }

    @MainActor
    func test_recentReleases_route_preRelease() async throws {
        // Test request handler - pre-releases only
        // setup
        // see RecentViewsTests.test_recentReleases_filter for filter results
        for idx in 1...12 {
            let major = idx / 3  // 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4
            let minor = idx % 3  // 1, 2, 0, 1, 2, 0, 1, 2, 0, 1, 2, 0
            let patch = idx % 2  // 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0
            let pre = idx <= 10 ? "" : "b1"
            let pkg = Package(id: UUID(), url: "\(idx)".asGithubUrl.url)
            try await pkg.save(on: app.db)
            try await Repository(package: pkg,
                           name: "pkg-\(idx)",
                           owner: "owner-\(idx)",
                           summary: "Summary")
                .create(on: app.db)
            try await Version(package: pkg,
                        commitDate: Date(timeIntervalSince1970: TimeInterval(idx)),
                        packageName: "pkg-\(idx)",
                        reference: .tag(.init(major, minor, patch, pre)),
                        url: "https://example.com/release-url")
                .save(on: app.db)
        }
        // make sure to refresh the materialized view
        try await RecentRelease.refresh(on: app.db)

        // MUT
        try await app.test(.GET, "releases.rss?pre=true", afterResponse: { @Sendable res async in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType,
                           .some(.init(type: "application", subType: "rss+xml")))
            // validation
            assertSnapshot(of: String(decoding: res.body.readableBytesView, as: UTF8.self),
                           as: .init(pathExtension: "xml", diffing: .lines))
        })
    }

}
