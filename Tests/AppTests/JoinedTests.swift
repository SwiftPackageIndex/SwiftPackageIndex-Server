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

import XCTest

class JoinedTests: AppTestCase {
    typealias JPR = Joined<Package, Repository>

    func test_query_owner_repository() throws {
        // setup
        let pkg = Package(url: "1")
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg, name: "bar", owner: "foo")
            .save(on: app.db).wait()
        do {  // inselected package
            let pkg = Package(url: "2")
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg, name: "bar2", owner: "foo")
                .save(on: app.db).wait()
        }

        // MUT
        let jpr = try JPR.query(on: app.db, owner: "foo", repository: "bar").wait()

        // validate
        XCTAssertEqual(jpr.package.id, pkg.id)
        XCTAssertEqual(jpr.repository?.owner, "foo")
        XCTAssertEqual(jpr.repository?.name, "bar")
    }

    func test_repository_access() throws {
        // Test accessing repository through the join vs through the package relation
        // setup
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p).save(on: app.db).wait()

        // MUT
        let jpr = try XCTUnwrap(JPR.query(on: app.db).first().wait())

        // validate
        XCTAssertNotNil(jpr.repository)
        // Assert the relationship is not loaded - that's the point of the join
        // In particular, this means that
        //    let repos = jpr.model.repositories
        // will fatalError. (This risk has always been there, it's just handled a
        // bit better now via `Joined<...>`.)
        // There is unfortunately no simple way to make this safe other that replacing/
        // wrapping all of the types involved.
        XCTAssertNil(jpr.model.$repositories.value)
    }

    func test_repository_update() throws {
        // Test updating the repository through the join
        // setup
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p).save(on: app.db).wait()
        let repo = try XCTUnwrap(JPR.query(on: app.db).first().wait()?.repository)
        XCTAssertEqual(repo.name, nil)
        repo.name = "foo"

        // MUT
        try repo.update(on: app.db).wait()

        // validate
        let r = try XCTUnwrap(Repository.query(on: app.db).first().wait())
        XCTAssertEqual(r.name, "foo")
    }

}
