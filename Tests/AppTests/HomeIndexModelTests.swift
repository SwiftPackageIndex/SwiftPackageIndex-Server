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

import XCTVapor


class HomeIndexModelTests: AppTestCase {

    func test_query() throws {
        // setup
        let pkgId = UUID()
        let pkg = Package(id: pkgId, url: "1".url)
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg,
                       name: "1",
                       owner: "foo").save(on: app.db).wait()
        try App.Version(package: pkg,
                        commitDate: Date(timeIntervalSince1970: 0),
                        packageName: "Package",
                        reference: .tag(.init(1, 2, 3))).save(on: app.db).wait()
        try RecentPackage.refresh(on: app.db).wait()
        try RecentRelease.refresh(on: app.db).wait()

        // MUT
        let m = try HomeIndex.Model.query(database: app.db).wait()

        // validate
        let createdAt = try XCTUnwrap(pkg.createdAt)
        XCTAssertEqual(m.recentPackages, [
            .init(
                date: "\(date: createdAt, relativeTo: Current.date())",
                link: .init(label: "Package", url: "/foo/1")
            )
        ])
        XCTAssertEqual(m.recentReleases, [
            .init(packageName: "Package",
                  version: "1.2.3",
                  date: "\(date: Date(timeIntervalSince1970: 0), relativeTo: Current.date())",
                  url: "/foo/1"),
        ])
    }

}
