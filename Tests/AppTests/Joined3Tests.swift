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

class Joined3Tests: AppTestCase {

    func test_query_no_version() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p).save(on: app.db).wait()

        // MUT
        let res = try Joined3<Package, Repository, Version>.query(on: app.db)
            .all()
            .wait()

        // validate
        XCTAssertEqual(res.map(\.model.id), [])
    }

    func test_query_multiple_versions() throws {
        // Ensure multiple versions don't multiply the package selection
        // setup
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p).save(on: app.db).wait()
        try Version(package: p, latest: .defaultBranch).save(on: app.db).wait()
        try Version(package: p, latest: .release).save(on: app.db).wait()

        // MUT
        let res = try Joined3<Package, Repository, Version>
            .query(on: app.db, version: .defaultBranch)
            .all()
            .wait()

        // validate
        XCTAssertEqual(res.map(\.model.id), [p.id])
    }


    func test_query_relationship_properties() throws {
        // Ensure relationship properties are populated by query
        // setup
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p, owner: "owner").save(on: app.db).wait()
        try Version(package: p,
                    latest: .defaultBranch,
                    packageName: "package name").save(on: app.db).wait()

        // MUT
        let res = try Joined3<Package, Repository, Version>
            .query(on: app.db, version: .defaultBranch)
            .all().wait()

        // validate
        XCTAssertEqual(res.map { $0.repository.owner }, ["owner"])
        XCTAssertEqual(res.map { $0.version.packageName }, ["package name"])
    }

    func test_query_missing_relations() throws {
        // Neither should be possible in practice, this is just ensuring we cannot
        // force unwrap the `repository` or `version` properties in the pathological
        // event, because there are no results to access the properties on.
        do {  // no repository
            let p = try savePackage(on: app.db, "1")
            try Version(package: p,
                        latest: .defaultBranch,
                        packageName: "package name").save(on: app.db).wait()

            // MUT
            let res = try Joined3<Package, Repository, Version>
                .query(on: app.db, version: .defaultBranch)
                .all().wait()

            // validate - result is empty, `res[0].repository` cannot be called
            XCTAssertTrue(res.isEmpty)
        }
        do {  // no version
            let p = try savePackage(on: app.db, "2")
            try Repository(package: p, owner: "owner").save(on: app.db).wait()

            // MUT
            let res = try Joined3<Package, Repository, Version>
                .query(on: app.db, version: .defaultBranch)
                .all().wait()

            // validate - result is empty, `res[0].repository` cannot be called
            XCTAssertTrue(res.isEmpty)
        }
    }

}
