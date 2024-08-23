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

import Vapor
import XCTest

class AuthorControllerTests: AppTestCase {

    func test_query() async throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        try await Repository(package: p, owner: "owner").save(on: app.db)
        try await Version(package: p, latest: .defaultBranch).save(on: app.db)

        // MUT
        let pkg = try await AuthorController.query(on: app.db, owner: "owner")

        // validate
        XCTAssertEqual(pkg.map(\.model.id), [p.id])
    }

    func test_query_no_version() async throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        try await Repository(package: p, owner: "owner").save(on: app.db)

        // MUT
        do {
            _ = try await AuthorController.query(on: app.db, owner: "owner")
            XCTFail("Expected Abort.notFound")
        } catch let error as Abort {
            // validate
            XCTAssertEqual(error.status, .notFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_query_sort_alphabetically() async throws {
        // setup
        for packageName in ["gamma", "alpha", "beta"] {
            let p = Package(url: "\(packageName)".url)
            try await p.save(on: app.db)
            try await Repository(package: p, owner: "owner").save(on: app.db)
            try await Version(package: p, latest: .defaultBranch, packageName: packageName).save(on: app.db)
        }

        // MUT
        let pkg = try await AuthorController.query(on: app.db, owner: "owner")

        // validate
        XCTAssertEqual(pkg.map(\.model.url), ["alpha", "beta", "gamma"])
    }

    func test_show_owner() async throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        try await Repository(package: p, owner: "owner").save(on: app.db)
        try await Version(package: p, latest: .defaultBranch).save(on: app.db)

        // MUT
        try await app.test(.GET, "/owner", afterResponse: { response async in
            XCTAssertEqual(response.status, .ok)
        })
    }

    func test_show_owner_empty() async throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        try await Repository(package: p, owner: "owner").save(on: app.db)
        try await Version(package: p, latest: .defaultBranch).save(on: app.db)

        // MUT
        try await app.test(.GET, "/fake-owner", afterResponse: { response async in
            XCTAssertEqual(response.status, .notFound)
        })
    }

}
