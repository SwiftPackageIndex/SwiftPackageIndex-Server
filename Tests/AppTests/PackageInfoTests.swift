// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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

import XCTest


class PackageInfoTests: AppTestCase {

    func test_title_package_name() throws {
        // Ensure title is populated from package.name()
        // setup
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p, name: "repo name", owner: "owner")
            .save(on: app.db).wait()
        try Version(package: p, latest: .defaultBranch, packageName: "package name")
            .save(on: app.db).wait()
        try p.$repositories.load(on: app.db).wait()
        try p.$versions.load(on: app.db).wait()

        // MUT
        let pkgInfo = PackageInfo(package: p)

        // validate
        XCTAssertEqual(pkgInfo?.title, "package name")
    }

    func test_title_repo_name() throws {
        // Ensure title is populated from repoName if package.name() is nil
        // setup
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p, name: "repo name", owner: "owner")
            .save(on: app.db).wait()
        try p.$repositories.load(on: app.db).wait()
        try p.$versions.load(on: app.db).wait()

        // MUT
        let pkgInfo = PackageInfo(package: p)

        // validate
        XCTAssertEqual(pkgInfo?.title, "repo name")
    }
}
