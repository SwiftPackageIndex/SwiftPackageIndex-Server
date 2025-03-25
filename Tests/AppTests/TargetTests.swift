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
import Testing
import Vapor


extension AllTests.TargetTests {

    @Test func save() async throws {
        try await withApp { app in
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
            let readBack = try #require(try await Target.query(on: app.db).first())
            #expect(readBack.id != nil)
            #expect(readBack.$version.id == v.id)
            #expect(readBack.createdAt != nil)
            #expect(readBack.updatedAt != nil)
            #expect(readBack.name == "target")
        }
    }

    @Test func delete_cascade() async throws {
        try await withApp { app in
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
                #expect(target != nil)
            }

            // MUT
            try await v.delete(on: app.db)

            // validate
            do {
                let target = try await Target.query(on: app.db).first()
                #expect(target == nil)
            }
        }
    }

}
