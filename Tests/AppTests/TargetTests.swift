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

import Fluent
import Vapor
import XCTVapor


final class TargetTests: ParallelizedAppTestCase {

    func test_save() async throws {
        // setup
        let v = Version()
        v.commit = "" // required field
        v.commitDate = .distantPast // required field
        v.reference = .branch("main")  // required field
        try await v.save(on: app.db)
        let t = try Target(version: v, name: "target")

        // MUT
        try await t.save(on: app.db)

        // validate
        let readBack = try await XCTUnwrapAsync(try await Target.query(on: app.db).first())
        XCTAssertNotNil(readBack.id)
        XCTAssertEqual(readBack.$version.id, v.id)
        XCTAssertNotNil(readBack.createdAt)
        XCTAssertNotNil(readBack.updatedAt)
        XCTAssertEqual(readBack.name, "target")
    }

    func test_delete_cascade() async throws {
        // setup
        let v = Version()
        v.commit = "" // required field
        v.commitDate = .distantPast // required field
        v.reference = .branch("main")  // required field
        try await v.save(on: app.db)
        let t = try Target(version: v, name: "target")
        try await t.save(on: app.db)
        do {
            let target = try await Target.query(on: app.db).first()
            XCTAssertNotNil(target)
        }

        // MUT
        try await v.delete(on: app.db)

        // validate
        do {
            let target = try await Target.query(on: app.db).first()
            XCTAssertNil(target)
        }
    }

}
