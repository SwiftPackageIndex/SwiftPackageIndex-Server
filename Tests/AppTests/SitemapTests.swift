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

import Plot
import SnapshotTesting
import XCTVapor


class SitemapTests: SnapshotTestCase {

    @MainActor
    func test_siteMapIndex() async throws {
        // Setup
        let packages = (0..<3).map { Package(url: "\($0)".url) }
        try await packages.save(on: app.db)
        try await packages.map { try Repository(package: $0, defaultBranch: "default",
                                                lastCommitDate: Current.date(), name: $0.url,
                                                owner: "foo") }.save(on: app.db)
        try await packages.map { try Version(package: $0, packageName: "foo",
                                             reference: .branch("default")) }.save(on: app.db)
        try await Search.refresh(on: app.db).get()

        let req = Request(application: app, on: app.eventLoopGroup.next())

        // MUT
        let siteMapIndex = try await SiteMapController.index(req: req)

        // Validation
        assertSnapshot(of: siteMapIndex.render(indentedBy: .spaces(2)),
                       as: .init(pathExtension: "xml", diffing: .lines))
    }

    func test_siteMapIndex_prod() async throws {
        // Ensure sitemap routing is configured in prod
        // Setup
        Current.environment = { .production }
        // We also need to set up a new app that's configured for production,
        // because app.test is not affected by Current overrides.
        let prodApp = try await setup(.production)
        defer { prodApp.shutdown() }

        // MUT
        try prodApp.test(.GET, "/sitemap.xml") { res in
            // Validation
            XCTAssertEqual(res.status, .ok)
        }
    }

    func test_siteMapIndex_dev() async throws {
        // Ensure we don't serve sitemaps in dev
        // app and Current.environment are configured for .development by default

        // MUT
        try app.test(.GET, "/sitemap.xml") { res in
            // Validation
            XCTAssertEqual(res.status, .notFound)
        }
    }

    @MainActor
    func test_siteMapStaticPages() async throws {
        let req = Request(application: app, on: app.eventLoopGroup.next())

        // MUT
        let siteMap = try await SiteMapController.staticPages(req: req)

        // Validation
        assertSnapshot(of: siteMap.render(indentedBy: .spaces(2)),
                       as: .init(pathExtension: "xml", diffing: .lines))
    }

    func test_siteMapStaticPages_prod() async throws {
        // Ensure sitemap routing is configured in prod
        Current.environment = { .production }
        // We also need to set up a new app that's configured for production,
        // because app.test is not affected by Current overrides.
        let prodApp = try await setup(.production)
        defer { prodApp.shutdown() }

        // MUT
        try prodApp.test(.GET, "/sitemap-static-pages.xml") { res in
            // Validation
            XCTAssertEqual(res.status, .ok)
        }
    }

    func test_siteMapStaticPages_dev() async throws {
        // Ensure we don't serve sitemaps in dev
        // app and Current.environment are configured for .development by default

        // MUT
        try app.test(.GET, "/sitemap-static-pages.xml") { res in
            // Validation
            XCTAssertEqual(res.status, .notFound)
        }
    }

    func test_linkablePathUrls() async throws {
        // setup
        let package = Package(url: URL(stringLiteral: "https://example.com/owner/repo0"))
        try await package.save(on: app.db)
        try await Repository(package: package, defaultBranch: "default",
                             lastCommitDate: Current.date(),
                             name: "Repo0", owner: "Owner").save(on: app.db)
        try await Version(package: package,
                          commit: "123456",
                          commitDate: .t0,
                          docArchives: [.init(name: "t1", title: "T1")],
                          latest: .defaultBranch,
                          packageName: "SomePackage",
                          reference: .branch("default"),
                          spiManifest: .init(builder: .init(configs: [.init(documentationTargets: ["t1", "t2"])]))).save(on: app.db)
        let packageResult = try await PackageController.PackageResult
            .query(on: app.db, owner: "owner", repository: "repo0")
        Current.siteURL = { "https://spi.com" }
        Current.fetchDocumentation = { client, url in
            guard url.path.hasSuffix("/owner/repo0/default/linkable-paths.json") else { throw Abort(.notFound) }
            return .init(status: .ok,
                         body: .init(string: """
                            [
                                "/documentation/foo/bar/1",
                                "/documentation/foo/bar/2",
                            ]
                            """)
            )
        }

        // MUT
        let urls = await PackageController.linkablePathUrls(client: app.client, packageResult: packageResult)

        XCTAssertEqual(urls, [
            "https://spi.com/Owner/Repo0/default/documentation/foo/bar/1",
            "https://spi.com/Owner/Repo0/default/documentation/foo/bar/2"
        ])
    }

    func test_linkablePathUrls_reference_pathEncoded() async throws {
        // Ensure branch names with / are properly "path encoded"
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2462
        // setup
        let package = Package(url: URL(stringLiteral: "https://example.com/owner/repo0"))
        try await package.save(on: app.db)
        try await Repository(package: package, defaultBranch: "a/b",
                             lastCommitDate: Current.date(),
                             name: "Repo0", owner: "Owner").save(on: app.db)
        try await Version(package: package,
                          commit: "123456",
                          commitDate: .t0,
                          docArchives: [.init(name: "t1", title: "T1")],
                          latest: .defaultBranch,
                          packageName: "SomePackage",
                          reference: .branch("a/b"),
                          spiManifest: .init(builder: .init(configs: [.init(documentationTargets: ["t1", "t2"])]))).save(on: app.db)
        let packageResult = try await PackageController.PackageResult
            .query(on: app.db, owner: "owner", repository: "repo0")
        Current.siteURL = { "https://spi.com" }
        Current.fetchDocumentation = { client, url in
            guard url.path.hasSuffix("/owner/repo0/a-b/linkable-paths.json") else { throw Abort(.notFound) }
            return .init(status: .ok,
                         body: .init(string: """
                            [
                                "/documentation/foo/bar/1",
                                "/documentation/foo/bar/2",
                            ]
                            """)
            )
        }

        // MUT
        let urls = await PackageController.linkablePathUrls(client: app.client, packageResult: packageResult)

        XCTAssertEqual(urls, [
            "https://spi.com/Owner/Repo0/a-b/documentation/foo/bar/1",
            "https://spi.com/Owner/Repo0/a-b/documentation/foo/bar/2"
        ])
    }

    @MainActor
    func test_siteMapForPackage_noDocs() async throws {
        // setup
        let package = Package(url: URL(stringLiteral: "https://example.com/owner/repo0"))
        try await package.save(on: app.db)
        try await Repository(package: package, defaultBranch: "default",
                             lastCommitDate: Current.date(),
                             name: "Repo0", owner: "Owner").save(on: app.db)
        try await Version(package: package, latest: .defaultBranch, packageName: "SomePackage",
                          reference: .branch("default")).save(on: app.db)
        let packageResult = try await PackageController.PackageResult
            .query(on: app.db, owner: "owner", repository: "repo0")

        // MUT
        let sitemap = try await SiteMapController.package(owner: packageResult.repository.owner,
                                                          repository: packageResult.repository.name,
                                                          lastActivityAt: packageResult.repository.lastActivityAt,
                                                          linkablePathUrls: [])
        let xml = sitemap.render(indentedBy: .spaces(2))

        // Validation
        assertSnapshot(of: xml, as: .init(pathExtension: "xml", diffing: .lines))
    }

    @MainActor
    func test_siteMapForPackage_withDocs() async throws {
        // setup
        let package = Package(url: URL(stringLiteral: "https://example.com/owner/repo0"))
        try await package.save(on: app.db)
        try await Repository(package: package, defaultBranch: "default",
                             lastCommitDate: Current.date(),
                             name: "Repo0", owner: "Owner").save(on: app.db)
        try await Version(package: package, latest: .defaultBranch, packageName: "SomePackage",
                          reference: .branch("default")).save(on: app.db)
        let packageResult = try await PackageController.PackageResult
            .query(on: app.db, owner: "owner", repository: "repo0")
        let linkablePathUrls = [
            "/documentation/semanticversion/semanticversion/minor",
            "/documentation/semanticversion/semanticversion/_(_:_:)-4ftn7",
            "/documentation/semanticversion/semanticversion/'...(_:)-40b95"
        ]

        // MUT
        let sitemap = try await SiteMapController.package(owner: packageResult.repository.owner,
                                                          repository: packageResult.repository.name,
                                                          lastActivityAt: packageResult.repository.lastActivityAt,
                                                          linkablePathUrls: linkablePathUrls)
        let xml = sitemap.render(indentedBy: .spaces(2))

        // Validation
        assertSnapshot(of: xml, as: .init(pathExtension: "xml", diffing: .lines))
    }

}
