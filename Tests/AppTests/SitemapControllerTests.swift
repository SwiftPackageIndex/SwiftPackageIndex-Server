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


class SitemapControllerTests: SnapshotTestCase {

    @MainActor
    func test_buildSiteMapIndex() async throws {
        let packages = (0..<3).map { Package(url: "\($0)".url) }
        try await packages.save(on: app.db)
        try await packages.map { try Repository(package: $0, defaultBranch: "default",
                                                lastCommitDate: Current.date(), name: $0.url,
                                                owner: "foo") }.save(on: app.db)
        try await packages.map { try Version(package: $0, packageName: "foo",
                                             reference: .branch("default")) }.save(on: app.db)
        try await Search.refresh(on: app.db).get()

        // MUT
        let siteMap = try await SiteMapController.buildIndex(db: app.db)

        assertSnapshot(matching: siteMap.render(indentedBy: .spaces(4)),
                       as: .init(pathExtension: "xml", diffing: .lines))
    }

    @MainActor
    func test_buildSiteMapStaticPages() async throws {
        // MUT
        let siteMap = SiteMapController.buildStaticPages()

        assertSnapshot(matching: siteMap.render(indentedBy: .spaces(4)),
                       as: .init(pathExtension: "xml", diffing: .lines))
    }

    @MainActor
    func test_buildMapForPackage() async throws {
        let package = Package(url: URL(stringLiteral: "https://example.com/owner/repo0"))
        try await package.save(on: app.db)
        try await Repository(package: package, defaultBranch: "default",
                             lastCommitDate: Current.date(),
                             name: "repo0", owner: "owner").save(on: app.db)
        try await Version(package: package, latest: .defaultBranch, packageName: "SomePackage",
                          reference: .branch("default")).save(on: app.db)

        // MUT
        let siteMap = try await SiteMapController.buildMapForPackage(db: app.db, owner: "owner", repository: "repo0")

        assertSnapshot(matching: siteMap.render(indentedBy: .spaces(4)),
                       as: .init(pathExtension: "xml", diffing: .lines))
    }
}
