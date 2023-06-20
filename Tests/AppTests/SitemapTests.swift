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

        // MUT
        try app.test(.GET, "/sitemap.xml") { res in
            // Validation
            XCTAssertEqual(res.status, .ok)
            assertSnapshot(matching: res.body.asString(), as: .init(pathExtension: "xml", diffing: .lines))
        }
    }

    @MainActor
    func test_siteMapStaticPages() async throws {
        // MUT
        try app.test(.GET, "/sitemap-static-pages.xml") { res in
            // Validation
            XCTAssertEqual(res.status, .ok)
            assertSnapshot(matching: res.body.asString(), as: .init(pathExtension: "xml", diffing: .lines))
        }
    }

    func test_siteMap_basic_request() async throws {
        // Test basic sitemap request
        // setup
        let package = Package(url: URL(stringLiteral: "https://example.com/owner/repo0"))
        try await package.save(on: app.db)
        try await Repository(package: package, defaultBranch: "default",
                             lastCommitDate: Current.date(),
                             name: "Repo0", owner: "Owner").save(on: app.db)
        try await Version(package: package, latest: .defaultBranch, packageName: "SomePackage",
                          reference: .branch("default")).save(on: app.db)

        // MUT
        try app.test(.GET, "/owner/repo0/sitemap.xml") { res in
            XCTAssertEqual(res.status, .ok)
        }
    }

    func test_linkableEntityUrls() async throws {
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
            guard url.path.hasSuffix("/owner/repo0/default/linkable-entities.json") else { throw Abort(.notFound) }
            return .init(status: .ok,
                         body: .init(string: """
                            [
                                { "path": "/documentation/foo/bar/1" },
                                { "path": "/documentation/foo/bar/2" },
                            ]
                            """)
            )
        }

        // MUT
        let urls = await PackageController.linkableEntityUrls(client: app.client, packageResult: packageResult)

        XCTAssertEqual(urls, [
            "https://spi.com/Owner/Repo0/default/documentation/foo/bar/1",
            "https://spi.com/Owner/Repo0/default/documentation/foo/bar/2"
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
        let sitemap = try await PackageController.siteMap(packageResult: packageResult, linkableEntityUrls: [])
        let xml = sitemap.render(indentedBy: .spaces(2))

        // Validation
        assertSnapshot(matching: xml, as: .init(pathExtension: "xml", diffing: .lines))
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
        let linkableEntitiesUlrs = [
            "/documentation/semanticversion/semanticversion/minor",
            "/documentation/semanticversion/semanticversion/_(_:_:)-4ftn7",
            "/documentation/semanticversion/semanticversion/'...(_:)-40b95"
        ]

        // MUT
        let sitemap = try await PackageController.siteMap(packageResult: packageResult,
                                                          linkableEntityUrls: linkableEntitiesUlrs)
        let xml = sitemap.render(indentedBy: .spaces(2))

        // Validation
        assertSnapshot(matching: xml, as: .init(pathExtension: "xml", diffing: .lines))
    }

}
