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

//    func test_fetchPackages() throws {
//        // Test fetching all record in the search view
//        // setup
//        let packages = (0..<3).map { Package(url: "\($0)".url) }
//        try packages.save(on: app.db).wait()
//        try packages.map { try Repository(package: $0, defaultBranch: "default",
//                                          name: $0.url, owner: "foo") }
//            .save(on: app.db)
//            .wait()
//        try packages.map { try Version(package: $0, packageName: "foo", reference: .branch("default")) }
//            .save(on: app.db)
//            .wait()
//        try Search.refresh(on: app.db).wait()
//
//        // MUT
//        let res = try SiteMap.fetchPackages(app.db).wait()
//
//        // validation
//        XCTAssertEqual(res, [
//            .init(owner: "foo", repository: "0"),
//            .init(owner: "foo", repository: "1"),
//            .init(owner: "foo", repository: "2"),
//        ])
//    }


//    func test_render() throws {
//        // setup
//        Current.siteURL = { "https://indexsite.com" }
//        let packages: [SiteMap.Package] = [
//            .init(owner: "foo1", repository: "bar1", hasDocs: true),
//            .init(owner: "foo2", repository: "bar2"),
//            .init(owner: "foo3", repository: "bar3"),
//        ]
//
//        // MUT
//        let xml = SiteURL.siteMap(with: packages).render(indentedBy: .spaces(2))
//
//        // MUT + validation
//        assertSnapshot(matching: xml, as: .init(pathExtension: "xml", diffing: .lines))
//    }

//    func test_sitemap_route() throws {
//        // setup
//        Current.siteURL = { "https://indexsite.com" }
//        let packages = (0..<3).map { Package(url: "\($0)".url) }
//        try packages.save(on: app.db).wait()
//        try packages.map { try Repository(package: $0, defaultBranch: "default",
//                                          name: $0.url, owner: "foo") }
//            .save(on: app.db)
//            .wait()
//        try packages.map { try Version(package: $0, packageName: "foo", reference: .branch("default")) }
//            .save(on: app.db)
//            .wait()
//        try Search.refresh(on: app.db).wait()
//
//        // MUT
//        try app.test(.GET, "sitemap.xml") { res in
//            XCTAssertEqual(res.status, .ok)
//            XCTAssertEqual(res.content.contentType,
//                           .some(.init(type: "text", subType: "xml")))
//            let xml = try XCTUnwrap(res.body.asString())
//            assertSnapshot(matching: xml, as: .init(pathExtension: "xml", diffing: .lines))
//        }
//    }
}
