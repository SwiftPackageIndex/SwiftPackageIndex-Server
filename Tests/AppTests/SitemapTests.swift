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

    @MainActor
    func test_siteMapForPackage_noDocs() async throws {
        return // Temporary

        let package = Package(url: URL(stringLiteral: "https://example.com/owner/repo0"))
        try await package.save(on: app.db)
        try await Repository(package: package, defaultBranch: "default",
                             lastCommitDate: Current.date(),
                             name: "Repo0", owner: "Owner").save(on: app.db)
        try await Version(package: package, latest: .defaultBranch, packageName: "SomePackage",
                          reference: .branch("default")).save(on: app.db)

        // MUT
        let req = Vapor.Request(application: app, url: "/owner/repo0/sitemap.xml", on: app.eventLoopGroup.next())
        let response = try await PackageController.siteMap(req: req)
        let body = try XCTUnwrap(response.body.string)

        // Validation
        assertSnapshot(matching: body, as: .init(pathExtension: "xml", diffing: .lines))
    }

    @MainActor
    func test_siteMapForPackage_withDocs() async throws {
        return // Temporary

        let linkableEntitiesJson = """
        [
            { "path": "/documentation/semanticversion/semanticversion/minor" },
            { "path": "/documentation/semanticversion/semanticversion/_(_:_:)-4ftn7" },
            { "path": "/documentation/semanticversion/semanticversion/'...(_:)-40b95" }
        ]
        """

        let package = Package(url: URL(stringLiteral: "https://example.com/owner/repo0"))
        try await package.save(on: app.db)
        try await Repository(package: package, defaultBranch: "default",
                             lastCommitDate: Current.date(),
                             name: "Repo0", owner: "Owner").save(on: app.db)
        try await Version(package: package, latest: .defaultBranch, packageName: "SomePackage",
                          reference: .branch("default")).save(on: app.db)

        // MUT
        let req = Vapor.Request(application: app, url: "/owner/repo0/sitemap.xml", on: app.eventLoopGroup.next())
        let response = try await PackageController.siteMap(req: req)
        let body = try XCTUnwrap(response.body.string)

        // Validation
        assertSnapshot(matching: body, as: .init(pathExtension: "xml", diffing: .lines))
    }

}
