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

import Vapor
import XCTest

class PackageController_routesTests: AppTestCase {

    func test_show() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db).wait()
        try Version(package: pkg, latest: .defaultBranch).save(on: app.db).wait()

        // MUT
        try app.test(.GET, "/owner/package") {
            XCTAssertEqual($0.status, .ok)
        }
    }

    func test_show_checkingGitHubRepository_notFound() throws {
        Current.fetchHTTPStatusCode = { _, _ in .notFound }

        // MUT
        try app.test(.GET, "/unknown/package") {
            XCTAssertEqual($0.status, .notFound)
        }
    }

    func test_show_checkingGitHubRepository_found() throws {
        Current.fetchHTTPStatusCode = { _, _ in .ok }

        // MUT
        try app.test(.GET, "/unknown/package") {
            XCTAssertEqual($0.status, .notFound)
        }
    }

    func test_readme() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db).wait()
        try Version(package: pkg, latest: .defaultBranch).save(on: app.db).wait()

        // MUT
        try app.test(.GET, "/owner/package/readme") {
            XCTAssertEqual($0.status, .ok)
        }
    }

    func test_releases() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db).wait()
        try Version(package: pkg, latest: .defaultBranch).save(on: app.db).wait()

        // MUT
        try app.test(.GET, "/owner/package/releases") {
            XCTAssertEqual($0.status, .ok)
        }
    }

    func test_builds() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db).wait()
        try Version(package: pkg, latest: .defaultBranch).save(on: app.db).wait()

        // MUT
        try app.test(.GET, "/owner/package/builds") {
            XCTAssertEqual($0.status, .ok)
        }
    }

    func test_maintainerInfo() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db).wait()
        try Version(package: pkg, latest: .defaultBranch, packageName: "pkg")
            .save(on: app.db).wait()

        // MUT
        try app.test(.GET, "/owner/package/information-for-package-maintainers") {
            XCTAssertEqual($0.status, .ok)
        }
    }

    func test_maintainerInfo_no_packageName() throws {
        // Ensure we display the page even if packageName is not set
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db).wait()
        try Version(package: pkg, latest: .defaultBranch, packageName: nil)
            .save(on: app.db).wait()

        // MUT
        try app.test(.GET, "/owner/package/information-for-package-maintainers") {
            XCTAssertEqual($0.status, .ok)
        }
    }

}
