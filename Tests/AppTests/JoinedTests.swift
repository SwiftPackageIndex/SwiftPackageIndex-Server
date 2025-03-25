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

import Testing


extension AllTests.JoinedTests {
    typealias JPR = Joined<Package, Repository>

    @Test func query_owner_repository() async throws {
        try await withApp { app in
            // setup
            let pkg = Package(url: "1")
            try await pkg.save(on: app.db)
            try await Repository(package: pkg, name: "bar", owner: "foo")
                .save(on: app.db)
            do {  // inselected package
                let pkg = Package(url: "2")
                try await pkg.save(on: app.db)
                try await Repository(package: pkg, name: "bar2", owner: "foo")
                    .save(on: app.db)
            }

            // MUT
            let jpr = try await JPR.query(on: app.db, owner: "foo", repository: "bar")

            // validate
            #expect(jpr.package.id == pkg.id)
            #expect(jpr.repository?.owner == "foo")
            #expect(jpr.repository?.name == "bar")
        }
    }

    @Test func repository_access() async throws {
        // Test accessing repository through the join vs through the package relation
        try await withApp { app in
            // setup
            let p = try await savePackage(on: app.db, "1")
            try await Repository(package: p).save(on: app.db)

            // MUT
            let jpr = try #require(try await JPR.query(on: app.db).first())

            // validate
            #expect(jpr.repository != nil)
            // Assert the relationship is not loaded - that's the point of the join
            // In particular, this means that
            //    let repos = jpr.model.repositories
            // will fatalError. (This risk has always been there, it's just handled a
            // bit better now via `Joined<...>`.)
            // There is unfortunately no simple way to make this safe other that replacing/
            // wrapping all of the types involved.
            #expect(jpr.model.$repositories.value == nil)
        }
    }

    @Test func repository_update() async throws {
        // Test updating the repository through the join
        try await withApp { app in
            // setup
            let p = try await savePackage(on: app.db, "1")
            try await Repository(package: p).save(on: app.db)

            let jpr = try #require(try await JPR.query(on: app.db).first())
            let repo = try #require(jpr.repository)
            #expect(repo.name == nil)
            repo.name = "foo"

            // MUT
            try await repo.update(on: app.db)

            // validate
            do { // test in-place updates
                #expect(repo.name == "foo")
                #expect(jpr.repository?.name == "foo")
            }
            do { // ensure value is persisted
                let r = try #require(try await Repository.query(on: app.db).first())
                #expect(r.name == "foo")
                let reloadedJPR = try #require(try await JPR.query(on: app.db).first())
                #expect(reloadedJPR.repository?.name == "foo")
            }
        }
    }

}
